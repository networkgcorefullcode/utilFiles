#!/bin/bash

# ===============================================
# SCRIPT DE CONFIGURACIÓN UPF PARA DOCKER COMPOSE
# ===============================================
# Versión simplificada específicamente diseñada para 
# entornos Docker Compose de 5G Core Network

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
DOCKER_NETWORK=${DOCKER_NETWORK:-"net5g"}
UPF_CONFIG_DIR=${UPF_CONFIG_DIR:-"/opt/bess/bessctl/conf"}
UPF_MODE=${UPF_MODE:-"sim"}

# Logging functions
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
cat << "EOF"
===============================================
    UPF DOCKER COMPOSE CONFIGURATION
===============================================
     ____  _____ ____  ____  
    | __ )| ____/ ___/ ___| 
    |  _ \|  _| \___ \___ \ 
    | |_) | |___ ___) |__) |
    |____/|_____|____/____/ 
                            
    User Plane Function Setup
===============================================
EOF
echo -e "${NC}"

# Verificar que estamos en Docker
check_docker_environment() {
    log_info "Verificando entorno Docker..."
    
    if [ -f /.dockerenv ]; then
        log_success "Ejecutándose dentro de contenedor Docker"
    else
        log_warning "No se detectó entorno Docker (/.dockerenv no existe)"
        log_info "Este script está optimizado para Docker Compose"
    fi
    
    # Verificar comandos requeridos
    command -v docker >/dev/null 2>&1 || {
        log_error "Docker no está instalado"
        return 1
    }
    
    return 0
}

# Verificar conectividad con servicios 5G
check_5g_services() {
    log_info "Verificando conectividad con servicios 5G Core..."
    
    local services=("smf" "nrf" "amf")
    local all_ok=true
    
    for service in "${services[@]}"; do
        if ping -c 1 -W 2 "$service" >/dev/null 2>&1; then
            log_success "✓ $service: Accesible"
        else
            log_warning "✗ $service: No accesible"
            all_ok=false
        fi
    done
    
    if [ "$all_ok" = true ]; then
        log_success "Todos los servicios 5G están accesibles"
    else
        log_warning "Algunos servicios no están accesibles - verificar docker-compose.yml"
    fi
    
    return 0
}

# Verificar red Docker
check_docker_network() {
    log_info "Verificando red Docker '$DOCKER_NETWORK'..."
    
    if docker network inspect "$DOCKER_NETWORK" >/dev/null 2>&1; then
        local gateway=$(docker network inspect "$DOCKER_NETWORK" | grep -o '"Gateway": "[^"]*"' | cut -d'"' -f4 | head -1)
        local subnet=$(docker network inspect "$DOCKER_NETWORK" | grep -o '"Subnet": "[^"]*"' | cut -d'"' -f4 | head -1)
        
        log_success "Red '$DOCKER_NETWORK' encontrada"
        log_info "  Gateway: $gateway"
        log_info "  Subnet: $subnet"
        
        # Exportar variables para uso posterior
        export DOCKER_GATEWAY="$gateway"
        export DOCKER_SUBNET="$subnet"
    else
        log_error "Red '$DOCKER_NETWORK' no encontrada"
        log_info "Redes disponibles:"
        docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
        return 1
    fi
    
    return 0
}

# Generar configuración UPF para Docker Compose
generate_upf_config() {
    local mode="${1:-sim}"
    
    log_info "Generando configuración UPF para modo: $mode"
    
    # Crear directorio si no existe
    mkdir -p "$UPF_CONFIG_DIR"
    
    # Configuración específica para Docker Compose
    cat > "$UPF_CONFIG_DIR/upf.jsonc" << EOF
{
    "_comment": "UPF Configuration for Docker Compose Environment",
    "mode": "$mode",
    "workers": 1,
    "max_sessions": 50000,
    "table_sizes": {
        "pdrLookup": 50000,
        "appQERLookup": 200000,
        "sessionQERLookup": 100000,
        "farLookup": 150000
    },
    "interfaces": {
        "access": {
            "ifname": "access",
            "device": "$mode"
        },
        "core": {
            "ifname": "core", 
            "device": "$mode"
        }
    },
    "access": {
        "ip": "172.18.0.100/24",
        "mac": "02:42:ac:12:00:64",
        "next_hop": {
            "ip": "${DOCKER_GATEWAY:-172.18.0.1}",
            "mac": "02:42:ac:12:00:01"
        }
    },
    "core": {
        "ip": "172.18.0.101/24", 
        "mac": "02:42:ac:12:00:65",
        "next_hop": {
            "ip": "${DOCKER_GATEWAY:-172.18.0.1}",
            "mac": "02:42:ac:12:00:01"
        }
    },
    "measure": true,
    "hwcksum": false,
    "gtppsc": false,
    "cpiface": {
        "dnn": "internet",
        "hostname": "upf",
        "http_port": "8080",
        "enable_notify": false,
        "notify_sockaddr": "/tmp/notifycp",
        "enable_ue_ip_alloc": false,
        "ue_ip_pool": "172.250.0.0/16"
    },
    "slice_rate_limit_config": {
        "n6_bps": 1000000000,
        "n6_burst_bytes": 12500000,
        "n3_bps": 1000000000,
        "n3_burst_bytes": 12500000
    },
    "enable_end_marker": false,
    "log_level": "trace",
    "gtpu_only": false,
    "p4rtc_server": "onos",
    "p4rtc_port": "9559",
    "access_ip": "${DOCKER_GATEWAY:-172.18.0.1}",
    "enable_p4rt": false
}
EOF
    
    log_success "Configuración UPF generada: $UPF_CONFIG_DIR/upf.jsonc"
    
    # Crear enlace simbólico para compatibilidad
    if [ ! -L "$UPF_CONFIG_DIR/upf.json" ]; then
        ln -sf upf.jsonc "$UPF_CONFIG_DIR/upf.json"
        log_info "Enlace simbólico creado: upf.json -> upf.jsonc"
    fi
}

# Verificar configuración final
verify_setup() {
    log_info "Verificando configuración final..."
    
    if [ -f "$UPF_CONFIG_DIR/upf.jsonc" ]; then
        log_success "✓ Archivo de configuración existe"
        
        # Verificar que el JSON es válido
        if command -v jq >/dev/null 2>&1; then
            if jq empty "$UPF_CONFIG_DIR/upf.jsonc" 2>/dev/null; then
                log_success "✓ Configuración JSON es válida"
            else
                log_warning "✗ Configuración JSON puede tener errores de sintaxis"
            fi
        else
            log_info "jq no disponible - omitiendo validación JSON"
        fi
        
        # Mostrar tamaño del archivo
        local size=$(stat -c%s "$UPF_CONFIG_DIR/upf.jsonc" 2>/dev/null || echo "unknown")
        log_info "Tamaño de configuración: $size bytes"
    else
        log_error "✗ Archivo de configuración no encontrado"
        return 1
    fi
    
    return 0
}

# Función principal
main() {
    local mode="${1:-$UPF_MODE}"
    
    log_info "Iniciando configuración UPF para Docker Compose..."
    log_info "Modo: $mode"
    log_info "Red Docker: $DOCKER_NETWORK"
    log_info "Directorio configuración: $UPF_CONFIG_DIR"
    
    # Ejecutar verificaciones
    check_docker_environment || exit 1
    check_docker_network || exit 1
    check_5g_services
    
    # Generar configuración
    generate_upf_config "$mode" || exit 1
    
    # Verificar resultado
    verify_setup || exit 1
    
    # Resumen final
    echo -e "${GREEN}"
    cat << "EOF"
===============================================
    ✓ CONFIGURACIÓN COMPLETADA CON ÉXITO
===============================================
EOF
    echo -e "${NC}"
    
    log_success "UPF configurado para Docker Compose"
    log_info "Configuración generada en: $UPF_CONFIG_DIR/upf.jsonc"
    log_info "Para iniciar BESS, ejecute el contenedor UPF en docker-compose"
    
    return 0
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
