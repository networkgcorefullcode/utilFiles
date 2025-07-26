#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2019 Intel Corporation

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

# Función para verificar y configurar HugePages
check_hugepages() {
    log_info "Verificando configuración de HugePages..."
    
    # Verificar si HugePages están montadas
    if ! mount | grep -q hugepages; then
        log_warning "HugePages no están montadas. Montando..."
        sudo mkdir -p /dev/hugepages
        sudo mount -t hugetlbfs nodev /dev/hugepages
    fi
    
    # Verificar HugePages disponibles
    hugepages_1g=$(cat /proc/meminfo | grep HugePages_Total | awk '{print $2}')
    hugepage_size=$(cat /proc/meminfo | grep Hugepagesize | awk '{print $2}')
    
    log_info "HugePages disponibles: $hugepages_1g de ${hugepage_size}KB cada una"
    
    # Verificar si tenemos suficientes HugePages (necesitamos al menos 2)
    if [ "$hugepages_1g" -lt 2 ]; then
        log_warning "Insuficientes HugePages configuradas (actual: $hugepages_1g, necesarias: 2)"
        log_warning "Configurando HugePages temporalmente..."
        
        # Intentar configurar HugePages temporalmente
        echo 2 | sudo tee /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages > /dev/null
        
        # Verificar si se configuraron correctamente
        new_hugepages=$(cat /proc/meminfo | grep HugePages_Total | awk '{print $2}')
        if [ "$new_hugepages" -ge 2 ]; then
            log_success "HugePages configuradas temporalmente: $new_hugepages"
            configure_grub_hugepages
        else
            log_error "No se pudieron configurar HugePages temporalmente"
            show_hugepages_setup_instructions
            return 1
        fi
    else
        log_success "HugePages configuradas correctamente: $hugepages_1g"
    fi
    
    # Verificar Transparent HugePages
    thp_status=$(cat /sys/kernel/mm/transparent_hugepage/enabled)
    if [[ "$thp_status" != *"[never]"* ]]; then
        log_warning "Transparent HugePages están habilitadas. Deshabilitando temporalmente..."
        echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
        log_success "Transparent HugePages deshabilitadas temporalmente"
    else
        log_success "Transparent HugePages ya están deshabilitadas"
    fi
}

# Función para configurar GRUB automáticamente (opcional)
configure_grub_hugepages() {
    log_info "¿Deseas configurar HugePages permanentemente en GRUB? (y/N)"
    read -r response
    
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        log_info "Configurando GRUB para HugePages permanentes..."
        
        # Backup del archivo GRUB actual
        sudo cp /etc/default/grub /etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)
        log_success "Backup de GRUB creado en /etc/default/grub.backup.*"
        
        # Verificar si ya existe configuración de HugePages en GRUB
        if grep -q "hugepages=" /etc/default/grub; then
            log_warning "Ya existe configuración de HugePages en GRUB"
            log_info "Archivo actual:"
            grep GRUB_CMDLINE_LINUX /etc/default/grub
        else
            # Agregar configuración de HugePages
            log_info "Agregando configuración de HugePages a GRUB..."
            
            # Leer línea actual de GRUB_CMDLINE_LINUX
            current_line=$(grep '^GRUB_CMDLINE_LINUX=' /etc/default/grub | head -1)
            
            if [ -n "$current_line" ]; then
                # Quitar las comillas y agregar parámetros de HugePages
                new_params="intel_iommu=on iommu=pt default_hugepagesz=1G hugepagesz=1G hugepages=2 transparent_hugepage=never"
                
                # Construir nueva línea
                if [[ "$current_line" == *'""'* ]]; then
                    # Línea vacía
                    new_line="GRUB_CMDLINE_LINUX=\"$new_params\""
                else
                    # Línea con contenido existente
                    existing_params=$(echo "$current_line" | sed 's/GRUB_CMDLINE_LINUX="\(.*\)"/\1/')
                    new_line="GRUB_CMDLINE_LINUX=\"$existing_params $new_params\""
                fi
                
                # Reemplazar línea en el archivo
                sudo sed -i "s|^GRUB_CMDLINE_LINUX=.*|$new_line|" /etc/default/grub
                
                log_success "GRUB configurado con HugePages"
                log_info "Nueva configuración:"
                grep GRUB_CMDLINE_LINUX /etc/default/grub
                
                # Actualizar GRUB
                log_info "Actualizando GRUB..."
                sudo update-grub
                
                log_success "GRUB actualizado exitosamente"
                log_warning "Reinicia el sistema para aplicar los cambios: sudo reboot"
                
            else
                log_error "No se encontró línea GRUB_CMDLINE_LINUX en /etc/default/grub"
            fi
        fi
    else
        log_info "Configuración de GRUB omitida. Usando configuración temporal."
    fi
}

# Función para mostrar instrucciones de configuración permanente
show_hugepages_setup_instructions() {
    echo -e "${YELLOW}"
    echo "==============================================="
    echo "    CONFIGURACIÓN PERMANENTE DE HUGEPAGES"
    echo "==============================================="
    echo -e "${NC}"
    
    log_warning "Para hacer la configuración permanente, ejecuta los siguientes comandos:"
    echo ""
    echo "1. Editar GRUB configuration:"
    echo "   sudo vim /etc/default/grub"
    echo ""
    echo "2. Agregar o modificar la línea GRUB_CMDLINE_LINUX:"
    echo "   GRUB_CMDLINE_LINUX=\"intel_iommu=on iommu=pt default_hugepagesz=1G hugepagesz=1G hugepages=2 transparent_hugepage=never\""
    echo ""
    echo "3. Actualizar GRUB:"
    echo "   sudo update-grub"
    echo ""
    echo "4. Reiniciar el sistema:"
    echo "   sudo reboot"
    echo ""
    echo "5. Verificar después del reinicio:"
    echo "   cat /proc/meminfo | grep -i hugepage"
    echo "   cat /sys/kernel/mm/transparent_hugepage/enabled"
    echo ""
    log_info "Presiona Enter para continuar con configuración temporal..."
    read -r
}

# TCP port of bess/web monitor
gui_port=8000
bessd_port=10514
metrics_port=8080

# Banner informativo
echo -e "${BLUE}"
echo "==============================================="
echo "           UPF BESS SETUP SCRIPT"
echo "==============================================="
echo -e "${NC}"
log_info "Este script configurará el UPF (User Plane Function) con BESS"
log_info "Verificando prerequisitos del sistema..."

# Driver options. Choose any one of the three
#
# "dpdk" set as default
# "af_xdp" uses AF_XDP sockets via DPDK's vdev for pkt I/O. This version is non-zc version. ZC version still needs to be evaluated.
# "af_packet" uses AF_PACKET sockets via DPDK's vdev for pkt I/O.
# "sim" uses Source() modules to simulate traffic generation
# "cndp" uses kernel AF-XDP. It supports ZC and XDP offload if driver and NIC supports it. It's tested on Intel 800 series n/w adapter.
# mode="dpdk"
#mode="cndp"
#mode="af_xdp"
#mode="af_packet"
mode="sim"

# Gateway interface(s)
#
# In the order of ("s1u/n3" "sgi/n6")
ifaces=("ens803f2" "ens803f3")

# Static IP addresses of gateway interface(s) in cidr format
#
# In the order of (s1u/n3 sgi/n6)
ipaddrs=(198.18.0.1/30 198.19.0.1/30)

# MAC addresses of gateway interface(s)
#
# In the order of (s1u/n3 sgi/n6)
macaddrs=(9e:b2:d3:34:ab:27 c2:9c:55:d4:8a:f6)

# Static IP addresses of the neighbors of gateway interface(s)
#
# In the order of (n-s1u/n3 n-sgi/n6)
nhipaddrs=(198.18.0.2 198.19.0.2)

# Static MAC addresses of the neighbors of gateway interface(s)
#
# In the order of (n-s1u/n3 n-sgi/n6)
nhmacaddrs=(22:53:7a:15:58:50 22:53:7a:15:58:50)

# IPv4 route table entries in cidr format per port
#
# In the order of ("{r-s1u/n3}" "{r-sgi/n6}")
routes=("11.1.1.128/25" "0.0.0.0/0")

num_ifaces=${#ifaces[@]}
num_ipaddrs=${#ipaddrs[@]}

# Set up static route and neighbor table entries of the SPGW/UPF
function setup_trafficgen_routes() {
	for ((i = 0; i < num_ipaddrs; i++)); do
		sudo ip netns exec pause ip neighbor add "${nhipaddrs[$i]}" lladdr "${nhmacaddrs[$i]}" dev "${ifaces[$i % num_ifaces]}"
		routelist=${routes[$i]}
		for route in $routelist; do
			sudo ip netns exec pause ip route add "$route" via "${nhipaddrs[$i]}" metric 100
		done
	done
}

# Assign IP address(es) of gateway interface(s) within the network namespace
function setup_addrs() {
	for ((i = 0; i < num_ipaddrs; i++)); do
		sudo ip netns exec pause ip addr add "${ipaddrs[$i]}" dev "${ifaces[$i % $num_ifaces]}"
	done
}

# Set up mirror links to communicate with the kernel
#
# These vdev interfaces are used for ARP + ICMP updates.
# ARP/ICMP requests are sent via the vdev interface to the kernel.
# ARP/ICMP responses are captured and relayed out of the dpdk ports.
function setup_mirror_links() {
	for ((i = 0; i < num_ifaces; i++)); do
		sudo ip netns exec pause ip link add "${ifaces[$i]}" type veth peer name "${ifaces[$i]}"-vdev
		sudo ip netns exec pause ip link set "${ifaces[$i]}" up
		sudo ip netns exec pause ip link set "${ifaces[$i]}-vdev" up
		sudo ip netns exec pause ip link set dev "${ifaces[$i]}" address "${macaddrs[$i]}"
	done
	setup_addrs
}

# Set up interfaces in the network namespace. For non-"dpdk" mode(s)
function move_ifaces() {
	for ((i = 0; i < num_ifaces; i++)); do
		sudo ip link set "${ifaces[$i]}" netns pause up
		sudo ip netns exec pause ip link set "${ifaces[$i]}" promisc off
		sudo ip netns exec pause ip link set "${ifaces[$i]}" xdp off
		if [ "$mode" == 'af_xdp' ]; then
			sudo ip netns exec pause ethtool --features "${ifaces[$i]}" ntuple off
			sudo ip netns exec pause ethtool --features "${ifaces[$i]}" ntuple on
			sudo ip netns exec pause ethtool -N "${ifaces[$i]}" flow-type udp4 action 0
			sudo ip netns exec pause ethtool -N "${ifaces[$i]}" flow-type tcp4 action 0
			sudo ip netns exec pause ethtool -u "${ifaces[$i]}"
		fi
		if [ "$mode" == 'cndp' ]; then
			# num queues
			num_q=1
			# start queue index
			start_q_idx=22
			# RSS using TC filter
			setup_tc "${ifaces[$i]}" $num_q $start_q_idx
		fi
	done
	setup_addrs
}

# Setup TC
# Note: This function is used only for cndp mode.
# Parameters: $1 = interface, $2 = number of queues, $3 = start queue index
function setup_tc() {
	# Interface name
	iface=$1
	# Number of queues
	num_q=$2
	# Start queue index
	sq_idx=$3
	sudo ip netns exec pause ethtool --offload $iface hw-tc-offload on
	# Create two traffic control groups for the two queue sets - set 0 and set 1.
	# queue set 1 will be used for dataplane traffic.
	# queue set 0 will handle rest of the traffic (eg: control plane traffic).
	# for e.g., 22@0 means 22 queues starting from queue id 0.
	# 4@22 mean 4 queues starting from queue id 22.
	sudo ip netns exec pause tc qdisc add dev $iface root mqprio \
		num_tc 2 map 0 1 queues $sq_idx@0 $num_q@$sq_idx hw 1 mode channel
	sudo ip netns exec pause tc qdisc add dev $iface clsact
}

# Add TC rules for N3/N6/N9 access and core interface.
# Note: This function is used only for cndp mode.
# Parameters: $1 = access interface, $2 = core interface
# Inner UE IP address range and GTPU port is hardcoded for now.
# UE IP address should match the generated traffic pattern.
function add_tc_rules() {
	# Encapuslated traffic N3 on access interface.
	# RSS GTPU filter (Note: hw_tc 1 has >1 queues which results in implict RSS)
	sudo ip netns exec pause tc filter add dev $1 protocol ip ingress \
		prio 1 flower src_ip 16.0.0.0/16 enc_dst_port 2152 skip_sw hw_tc 1
	# List TC rules on access interface.
	sudo ip netns exec pause tc filter show dev $1 ingress

	# Encapsulated traffic N9 on core interface.
	# RSS GTPU filter (Note: hw_tc 1 has >1 queues which results in implict RSS)
	sudo ip netns exec pause tc filter add dev $2 protocol ip ingress \
		prio 1 flower dst_ip 16.0.0.0/16 enc_dst_port 2152 skip_sw hw_tc 1
	# un-encapsulated traffic N6 on core interface
	sudo ip netns exec pause tc filter add dev $2 protocol ip ingress \
		prio 1 flower dst_ip 16.0.0.0/16 skip_sw hw_tc 1
	# List TC rules on core interface.
	sudo ip netns exec pause tc filter show dev $2 ingress
}

# Stop previous instances of bess* before restarting
docker stop pause bess bess-routectl bess-web bess-pfcpiface || true
docker rm -f pause bess bess-routectl bess-web bess-pfcpiface || true
sudo rm -rf /var/run/netns/pause

# Verificar y configurar HugePages antes de continuar
check_hugepages

cd ../upf

# Build
make docker-build

if [ "$mode" == 'dpdk' ]; then
	DEVICES=${DEVICES:-'--device=/dev/vfio/48 --device=/dev/vfio/49 --device=/dev/vfio/vfio'}
	PRIVS='--cap-add IPC_LOCK'

elif [[ "$mode" == 'af_xdp' || "$mode" == 'cndp' ]]; then
	PRIVS='--privileged'

elif [ "$mode" == 'af_packet' ]; then
	PRIVS='--cap-add IPC_LOCK'
fi

# Run pause
docker run --name pause -td --restart unless-stopped \
	-p $bessd_port:$bessd_port \
	-p $gui_port:$gui_port \
	-p $metrics_port:$metrics_port \
	--hostname $(hostname) \
	k8s.gcr.io/pause

# Emulate CNI + init container
sudo mkdir -p /var/run/netns
sandbox=$(docker inspect --format='{{.NetworkSettings.SandboxKey}}' pause)
sudo ln -s "$sandbox" /var/run/netns/pause

case $mode in
"dpdk" | "sim") setup_mirror_links ;;
"af_xdp" | "af_packet")
	move_ifaces
	# Make sure that kernel does not send back icmp dest unreachable msg(s)
	sudo ip netns exec pause iptables -I OUTPUT -p icmp --icmp-type port-unreachable -j DROP
	;;
"cndp")
	move_ifaces
	add_tc_rules "${ifaces[0]}" "${ifaces[1]}"
	;;
*) ;;

esac

# Setup trafficgen routes
if [ "$mode" != 'sim' ]; then
	setup_trafficgen_routes
fi

# Specify per-socket hugepages to allocate (in MBs) by bess daemon (default: 1024)
HUGEPAGES=''
# Use more hugepages for CNDP
if [ "$mode" == 'cndp' ]; then
	HUGEPAGES='-m 2048'
fi

cd ..
cp utilFiles/VERSION .

# Run bessd
docker run --name bess -td --restart unless-stopped \
	--cpuset-cpus=0-1 \
	--ulimit memlock=-1 -v /dev/hugepages:/dev/hugepages \
	-v "$PWD/configs_files/docker_compose_config/conf_bess":/opt/bess/bessctl/conf \
	--net container:pause \
	$PRIVS \
	$DEVICES \
	upf-epc-bess:"$(<VERSION)" -grpc-url=0.0.0.0:$bessd_port $HUGEPAGES

docker logs bess

# Sleep for a couple of secs before setting up the pipeline
sleep 10
docker exec bess ./bessctl run up4
sleep 10

# Run bess-web
docker run --name bess-web -d --restart unless-stopped \
	--net container:bess \
	--entrypoint bessctl \
	upf-epc-bess:"$(<VERSION)" http 0.0.0.0 $gui_port

# Run bess-pfcpiface depending on mode type
docker run --name bess-pfcpiface -td --restart on-failure \
	--net container:pause \
	-v "$PWD/configs_files/docker_compose_config/upf.jsonc":/conf/upf.jsonc \
	upf-epc-pfcpiface:"$(<VERSION)" \
	-config /conf/upf.jsonc

# Don't run any other container if mode is "sim"
if [ "$mode" == 'sim' ]; then
	exit
fi

# Run bess-routectl
docker run --name bess-routectl -td --restart unless-stopped \
	-v "$PWD/configs_files/docker_compose_config/route_control.py":/route_control.py \
	--net container:pause --pid container:bess \
	--entrypoint /route_control.py \
	upf-epc-bess:"$(<VERSION)" -i "${ifaces[@]}"
