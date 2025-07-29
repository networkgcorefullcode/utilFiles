#!/bin/bash

# --- Colores y Funciones de Logging ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Función Principal de Verificación y Configuración ---
check_and_configure_hugepages() {
    log_info "Verificando la configuración de HugePages para DPDK/BESS..."

    # Deshabilitar Transparent Huge Pages (siempre es una buena práctica)
    if [[ "$(cat /sys/kernel/mm/transparent_hugepage/enabled)" != *"[never]"* ]]; then
        log_warning "Transparent HugePages están habilitadas. Deshabilitando temporalmente..."
        echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
        log_success "Transparent HugePages deshabilitadas temporalmente."
    else
        log_success "Transparent HugePages ya están correctamente deshabilitadas."
    fi

    # Montar el sistema de archivos de HugePages si no está montado
    if ! mount | grep -q 'on /dev/hugepages type hugetlbfs'; then
        log_warning "El sistema de archivos hugetlbfs no está montado."
        log_info "Montando /dev/hugepages..."
        sudo mkdir -p /dev/hugepages
        sudo mount -t hugetlbfs none /dev/hugepages
        log_success "/dev/hugepages montado correctamente."
    else
        log_success "/dev/hugepages ya está montado."
    fi

    # # Preguntar al usuario qué tamaño de página configurar
    # echo
    # log_info "Elige el tamaño de HugePage que deseas configurar:"
    # echo "  1) 1GB (Recomendado para máximo rendimiento, requiere REINICIO)"
    # echo "  2) 2MB (Más flexible, puede configurarse sin reiniciar si la memoria no está fragmentada)"
    # read -p "Opción [1]: " page_choice
    # page_choice=${page_choice:-1} # Por defecto es 1

    # if [ "$page_choice" -eq 1 ]; then
    #     configure_1g_pages
    # elif [ "$page_choice" -eq 2 ]; then
    #     configure_2m_pages
    # else
    #     log_error "Opción no válida. Saliendo."
    #     exit 1
    # fi
    log_info "Configurando HugePages de 1GB"
    configure_1g_pages
}

# --- Función para configurar HugePages de 1GB ---
configure_1g_pages() {
    local pages_needed=4 # Edita este valor según tus necesidades (x páginas de 1GB = xGB total)
    log_info "Configurando para ${pages_needed} páginas de 1GB..."

    # Verificar si ya están configuradas
    local current_size=$(awk '/Hugepagesize/ {print $2}' /proc/meminfo)
    local current_total=$(awk '/HugePages_Total/ {print $2}' /proc/meminfo)

    if [ "$current_size" -eq 1048576 ] && [ "$current_total" -ge "$pages_needed" ]; then
        log_success "Ya tienes ${current_total} HugePages de 1GB configuradas. ¡Todo listo!"
        return 0
    fi

    log_warning "La configuración de HugePages de 1GB requiere modificar GRUB y reiniciar."
    log_info "Este script puede intentar hacerlo por ti."
    read -p "¿Deseas continuar y modificar GRUB automáticamente? (y/N): " response

    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        show_manual_instructions_1g
        exit 1
    fi

    # Configuración de GRUB

    # ----- Bloque de sed DEFINITIVO -----

local grub_file="/etc/default/grub"
local params="default_hugepagesz=1G hugepagesz=1G hugepages=${pages_needed}"

log_info "Haciendo backup de ${grub_file}..."
sudo cp "${grub_file}" "${grub_file}.backup.$(date +%F-%T)"

log_info "Modificando la línea GRUB_CMDLINE_LINUX en ${grub_file}..."

# Primero, lee el contenido actual entre las comillas
# Usamos `grep` y luego `cut` para aislar solo lo que está dentro de las comillas
current_params=$(grep '^GRUB_CMDLINE_LINUX=' "${grub_file}" | cut -d'"' -f2)

# Ahora, eliminamos cualquier parámetro de hugepages antiguo del contenido actual
# Usamos `echo` y `sed` en una tubería para no modificar el archivo aún
clean_params=$(echo "${current_params}" | sed -E 's/default_hugepagesz=\S*//g; s/hugepagesz=\S*//g; s/hugepages=[0-9]*//g; s/  */ /g; s/^ *//; s/ *$//')

# Construimos la nueva línea completa
new_line="GRUB_CMDLINE_LINUX=\"${params} ${clean_params}\""

# Finalmente, reemplazamos la línea completa en el archivo, lo que es mucho más seguro
# Usamos un delimitador diferente (#) para `sed` para evitar conflictos con las comillas
sudo sed -i "s#^GRUB_CMDLINE_LINUX=.*#${new_line}#" "${grub_file}"


log_success "Archivo GRUB modificado:"
grep --color=auto "GRUB_CMDLINE_LINUX" "${grub_file}"
    log_info "Actualizando GRUB..."
    if sudo update-grub; then
        log_success "GRUB actualizado."
        log_warning "¡REINICIO NECESARIO! Por favor, ejecuta 'sudo reboot' para aplicar los cambios."
        log_info "Después de reiniciar, vuelve a ejecutar este script para verificar la configuración."
    else
        log_error "Falló la actualización de GRUB. Revisa los errores."
        log_info "Tu configuración original está en ${grub_file}.backup"
    fi
    exit 0
}

# # --- Función para configurar HugePages de 2MB ---
# configure_2m_pages() {
#     local pages_needed=1024 # Pedimos 2GB (1024 * 2MB)
#     log_info "Configurando para ${pages_needed} páginas de 2MB (Total 2GB)..."

#     log_info "Intentando configurar en caliente (sin reiniciar)..."
#     echo ${pages_needed} | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages > /dev/null

#     local current_total=$(awk '/HugePages_Total/ {print $2}' /proc/meminfo)
#     local current_size=$(awk '/Hugepagesize/ {print $2}' /proc/meminfo)

#     if [ "$current_size" -eq 2048 ] && [ "$current_total" -ge "$pages_needed" ]; then
#         log_success "¡Éxito! Se configuraron ${current_total} HugePages de 2MB."
#         return 0
#     else
#         log_error "No se pudieron configurar las HugePages en caliente (actual: ${current_total}, pedidas: ${pages_needed})."
#         log_warning "Esto se debe probablemente a la fragmentación de la memoria."
#         show_manual_instructions_2m
#         exit 1
#     fi
# }

# --- Funciones de Instrucciones Manuales ---
show_manual_instructions_1g() {
    log_warning "Configuración automática cancelada. Pasos manuales:"
    echo "1. Edita GRUB: sudo nano /etc/default/grub"
    echo "2. Añade a GRUB_CMDLINE_LINUX: default_hugepagesz=1G hugepagesz=1G hugepages=4"
    echo "3. Actualiza GRUB: sudo update-grub"
    echo "4. Reinicia: sudo reboot"
    echo "5. Verifica con: cat /proc/meminfo | grep -i huge (para ver si los parámetros se aplicaron)"
}

# show_manual_instructions_2m() {
#     log_warning "Para asegurar la configuración de 2MB, debes reservarlas al arrancar:"
#     echo "Opción A) Usando sysctl (recomendado):"
#     echo "1. Crea/Edita el archivo: sudo nano /etc/sysctl.d/99-hugepages.conf"
#     echo "2. Añade la línea: vm.nr_hugepages = 1024"
#     echo "3. Reinicia o aplica con: sudo sysctl -p /etc/sysctl.d/99-hugepages.conf"
#     echo ""
#     echo "Opción B) Usando GRUB:"
#     echo "1. Edita GRUB: sudo nano /etc/default/grub"
#     echo "2. Añade a GRUB_CMDLINE_LINUX: hugepages=1024"
#     echo "3. Actualiza y reinicia."
# }

# --- Punto de Entrada del Script ---
check_and_configure_hugepages
