#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2024 Network G Core Full Code
#
# Script para construir el entorno completo de desarrollo 5G
# Ejecuta docker_setup.sh para UPF y luego levanta todos los servicios

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Banner
echo -e "${BLUE}"
echo "==============================================="
echo "    5G CORE DEVELOPMENT ENVIRONMENT BUILDER"
echo "==============================================="
echo -e "${NC}"

# Verificar que estamos en el directorio correcto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f "docker_setup.sh" ] || [ ! -f "docker-compose-ui.yml" ]; then
    log_error "Los archivos necesarios no se encuentran en el directorio actual:"
    log_error "  - docker_setup.sh"
    log_error "  - docker-compose-ui.yml"
    log_error "Asegúrate de ejecutar este script desde el directorio utilFiles"
    exit 1
fi

log_info "Directorio de trabajo: $SCRIPT_DIR"

# Función para limpiar contenedores anteriores
cleanup_containers() {
    log_info "Limpiando contenedores anteriores..."
    
    # Parar docker-compose si está corriendo
    if docker-compose -f docker-compose-ui.yml ps -q 2>/dev/null | grep -q .; then
        log_warning "Parando servicios de docker-compose..."
        docker-compose -f docker-compose-ui.yml down -v 2>/dev/null || true
    fi
    
    # Limpiar contenedores del UPF que puedan estar corriendo
    log_warning "Parando contenedores UPF existentes..."
    docker stop pause bess bess-routectl bess-web bess-pfcpiface 2>/dev/null || true
    docker rm -f pause bess bess-routectl bess-web bess-pfcpiface 2>/dev/null || true
    
    # Limpiar namespace de red
    sudo rm -rf /var/run/netns/pause 2>/dev/null || true
    
    log_success "Limpieza completada"
}

# Función para verificar prerequisitos
check_prerequisites() {
    log_info "Verificando prerequisitos..."
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker no está instalado"
        exit 1
    fi
    
    # Verificar Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose no está instalado"
        exit 1
    fi
    
    # Verificar Task (para UPF build)
    if ! command -v task &> /dev/null; then
        log_warning "Task no está instalado. El build del UPF podría fallar."
        log_info "Para instalar Task: https://taskfile.dev/installation/"
    fi
    
    # Verificar permisos sudo
    if ! sudo -n true 2>/dev/null; then
        log_warning "Se requieren permisos sudo para configurar networking del UPF"
    fi
    
    log_success "Prerequisitos verificados"
}

# Función para generar certificados TLS si no existen
setup_certificates() {
    log_info "Verificando certificados TLS..."
    
    if [ ! -d "certs" ] || [ ! -f "certs/ca.crt" ]; then
        log_warning "Certificados no encontrados. Generando..."
        
        if [ -f "generate_tls_certs.sh" ]; then
            chmod +x generate_tls_certs.sh
            ./generate_tls_certs.sh
            log_success "Certificados TLS generados"
        else
            log_error "Script generate_tls_certs.sh no encontrado"
            log_error "Los servicios podrían fallar sin certificados TLS"
        fi
    else
        log_success "Certificados TLS encontrados"
    fi
}

# Función para configurar MongoDB
setup_mongodb_scripts() {
    log_info "Verificando scripts de MongoDB..."
    
    # Verificar mongo-setup.sh
    if [ ! -f "mongo-setup.sh" ]; then
        log_warning "Creando script mongo-setup.sh..."
        cat > mongo-setup.sh << 'EOF'
#!/bin/bash
sleep 10
mongosh --host mongodb:27017 <<EOF
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongodb:27017" }
  ]
})
EOF
EOF
        chmod +x mongo-setup.sh
        log_success "Script mongo-setup.sh creado"
    fi
    
    # Verificar mongo-init.js
    if [ ! -f "mongo-init.js" ]; then
        log_warning "Creando script mongo-init.js..."
        cat > mongo-init.js << 'EOF'
// Inicialización de MongoDB para 5G Core
use admin;
db.createUser({
  user: "sdcore",
  pwd: "sdcore123",
  roles: [
    { role: "readWrite", db: "sdcore_amf" },
    { role: "readWrite", db: "sdcore_smf" },
    { role: "readWrite", db: "sdcore_nrf" },
    { role: "readWrite", db: "sdcore_ausf" },
    { role: "readWrite", db: "sdcore_udm" },
    { role: "readWrite", db: "sdcore_udr" },
    { role: "readWrite", db: "sdcore_pcf" },
    { role: "readWrite", db: "sdcore_nssf" }
  ]
});
EOF
        log_success "Script mongo-init.js creado"
    fi
}

# Función principal para ejecutar docker_setup.sh
run_upf_setup() {
    log_info "Ejecutando docker_setup.sh para configurar UPF..."
    
    if [ ! -f "docker_setup.sh" ]; then
        log_error "docker_setup.sh no encontrado"
        exit 1
    fi
    
    # Hacer el script ejecutable
    chmod +x docker_setup.sh
    
    # Ejecutar docker_setup.sh
    log_info "Iniciando configuración del UPF..."
    if ./docker_setup.sh; then
        log_success "UPF configurado exitosamente"
    else
        log_error "Error al configurar UPF"
        log_warning "Continuando con el resto de servicios..."
    fi
}

# Función para levantar servicios con docker-compose
run_docker_compose() {
    log_info "Levantando servicios 5G con docker-compose..."
    
    # Construir imágenes primero
    log_info "Construyendo imágenes Docker..."
    if docker-compose -f docker-compose-ui.yml build --no-cache; then
        log_success "Imágenes construidas exitosamente"
    else
        log_error "Error al construir imágenes"
        exit 1
    fi
    
    # Levantar servicios
    log_info "Iniciando servicios..."
    if docker-compose -f docker-compose-ui.yml up -d; then
        log_success "Servicios iniciados exitosamente"
    else
        log_error "Error al iniciar servicios"
        exit 1
    fi
    
    # Esperar un poco para que los servicios se estabilicen
    log_info "Esperando que los servicios se estabilicen..."
    sleep 15
    
    # Mostrar estado de los servicios
    log_info "Estado de los servicios:"
    docker-compose -f docker-compose-ui.yml ps
}

# Función para mostrar información del entorno
show_environment_info() {
    echo -e "${GREEN}"
    echo "==============================================="
    echo "    ENTORNO 5G DESPLEGADO EXITOSAMENTE"
    echo "==============================================="
    echo -e "${NC}"
    
    log_info "Servicios disponibles:"
    echo "  📡 AMF (Access and Mobility Management):     http://localhost:8001"
    echo "  🔐 AUSF (Authentication Server):             http://localhost:8002"
    echo "  📋 NRF (Network Repository Function):        http://localhost:8003"
    echo "  🎯 NSSF (Network Slice Selection):           http://localhost:8004"
    echo "  📊 PCF (Policy Control Function):            http://localhost:8005"
    echo "  🔄 SMF (Session Management Function):        http://localhost:8006"
    echo "  👤 UDM (Unified Data Management):            http://localhost:8007"
    echo "  💾 UDR (Unified Data Repository):            http://localhost:8008"
    echo "  🌐 WebUI (Management Console):               http://localhost:5000"
    echo "  🗄️  MongoDB Express (Database Viewer):       http://localhost:8081"
    echo ""
    echo "  🔧 MongoDB (Direct Access):                  localhost:27017"
    echo ""
    
    log_info "Credenciales para MongoDB Express:"
    echo "  👤 Usuario: admin"
    echo "  🔑 Contraseña: admin123"
    echo ""
    
    log_info "Comandos útiles:"
    echo "  📋 Ver logs:          docker-compose -f docker-compose-ui.yml logs -f [servicio]"
    echo "  ⏹️  Parar servicios:   docker-compose -f docker-compose-ui.yml down"
    echo "  🔄 Reiniciar:         docker-compose -f docker-compose-ui.yml restart [servicio]"
    echo "  🐚 Shell en container: docker exec -it [container_name] /bin/bash"
    echo ""
    
    log_success "¡Entorno 5G listo para desarrollo!"
}

# Función para manejar señales de interrupción
cleanup_on_exit() {
    log_warning "Interrumpido por el usuario"
    log_info "Para limpiar el entorno ejecuta:"
    echo "  docker-compose -f docker-compose-ui.yml down -v"
    echo "  docker stop pause bess bess-routectl bess-web bess-pfcpiface 2>/dev/null || true"
    echo "  docker rm -f pause bess bess-routectl bess-web bess-pfcpiface 2>/dev/null || true"
    exit 1
}

# Configurar manejo de señales
trap cleanup_on_exit SIGINT SIGTERM

# Función principal
main() {
    log_info "Iniciando construcción del entorno de desarrollo 5G..."
    
    # Ejecutar pasos
    check_prerequisites
    cleanup_containers
    setup_certificates
    setup_mongodb_scripts
    run_upf_setup
    run_docker_compose
    show_environment_info
    
    log_success "¡Entorno de desarrollo 5G completamente desplegado!"
}

# Verificar argumentos de línea de comandos
case "${1:-}" in
    --help|-h)
        echo "Uso: $0 [opciones]"
        echo ""
        echo "Opciones:"
        echo "  --help, -h        Mostrar esta ayuda"
        echo "  --cleanup-only    Solo limpiar contenedores existentes"
        echo "  --no-upf          Omitir configuración del UPF"
        echo ""
        echo "Este script configura un entorno completo de desarrollo 5G:"
        echo "1. Ejecuta docker_setup.sh para configurar UPF"
        echo "2. Levanta todos los servicios 5G con docker-compose-ui.yml"
        exit 0
        ;;
    --cleanup-only)
        log_info "Solo ejecutando limpieza..."
        cleanup_containers
        log_success "Limpieza completada"
        exit 0
        ;;
    --no-upf)
        log_info "Omitiendo configuración del UPF..."
        check_prerequisites
        cleanup_containers
        setup_certificates
        setup_mongodb_scripts
        run_docker_compose
        show_environment_info
        exit 0
        ;;
    "")
        # Ejecutar normalmente
        main
        ;;
    *)
        log_error "Opción desconocida: $1"
        log_info "Usa --help para ver las opciones disponibles"
        exit 1
        ;;
esac
