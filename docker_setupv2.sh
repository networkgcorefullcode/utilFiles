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



# TCP port of bess/web monitor
gui_port=8085
bessd_port=10514
metrics_port=8080

# Banner informativo
echo -e "${BLUE}"
echo "==============================================="
echo "       UPF BESS DOCKER COMPOSE SETUP"
echo "==============================================="
echo -e "${NC}"
log_info "Este script configurará el UPF (User Plane Function) con BESS para Docker Compose"
log_info "Verificando prerequisitos del sistema..."

# Detectar si estamos en un entorno Docker
DOCKER_ENV=true
# Driver options para entorno containerizado
mode="sim"  # Usar simulación por defecto en contenedores

# Red de Docker Compose
DOCKER_NETWORK=${DOCKER_NETWORK:-"net5g"}

log_info "Configurando para entorno Docker Compose..."

# Interfaces virtuales en lugar de físicas
ifaces=("access" "core")

# IPs internas de Docker (obtenidas dinámicamente)
# Estas se configurarán automáticamente por Docker
ipaddrs=("172.18.0.100/24" "172.18.0.101/24")

# MACs virtuales
macaddrs=("02:42:ac:12:00:64" "02:42:ac:12:00:65")

# Gateway de Docker (se detecta automáticamente)
DOCKER_GW=$(ip route | grep $DOCKER_NETWORK | awk '{print $1}' | head -1)
nhipaddrs=("172.18.0.1" "172.18.0.1")  # Gateway de Docker
nhmacaddrs=("02:42:ac:12:00:01" "02:42:ac:12:00:01")

# Rutas para entorno Docker
routes=("10.250.0.0/16" "0.0.0.0/0")  # UE pool y default

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

# ================================================
# FUNCIONES PARA DOCKER COMPOSE
# ================================================

# Configuración específica para entorno Docker
function setup_docker_environment() {
    log_info "Configurando entorno Docker Compose..."
    
    # Verificar conectividad con otros servicios
    log_info "Verificando conectividad con servicios 5G..."
    
    # Verificar conectividad con SMF (requerido para UPF)
    if ping -c 1 -W 2 smf >/dev/null 2>&1; then
        log_success "Conectividad con SMF: OK"
    else
        log_warning "SMF no accesible - verificar docker-compose.yml"
    fi
    
    # Verificar conectividad con NRF  
    if ping -c 1 -W 2 nrf >/dev/null 2>&1; then
        log_success "Conectividad con NRF: OK"
    else
        log_warning "NRF no accesible - verificar docker-compose.yml"
    fi
    
    # Verificar red Docker
    local network_info=$(docker network inspect "$DOCKER_NETWORK" 2>/dev/null)
    if [ $? -eq 0 ]; then
        log_success "Red Docker '$DOCKER_NETWORK' encontrada"
        local gateway=$(echo "$network_info" | grep -o '"Gateway": "[^"]*"' | cut -d'"' -f4)
        log_info "Gateway de red: $gateway"
    else
        log_error "Red Docker '$DOCKER_NETWORK' no encontrada"
        log_info "Redes disponibles:"
        docker network ls
        return 1
    fi
    
    # No necesitamos configurar interfaces físicas en Docker
    log_info "Usando interfaces virtuales para simulación"
    
    return 0
}

# Configurar BESS para Docker Compose
function bessctl_configure_docker() {
    local mode="$1"
    
    log_info "Generando configuración BESS para Docker Compose..."
    
    # Crear directorio de configuración si no existe
    mkdir -p "${confpath}"
    
    # Generar configuración específica para Docker
    cat > "${confpath}/upf.jsonc" << EOF
{
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
        "ip": "${ipaddrs[0]}",
        "mac": "${macaddrs[0]}",
        "next_hop": {
            "ip": "${nhipaddrs[0]}",
            "mac": "${nhmacaddrs[0]}"
        }
    },
    "core": {
        "ip": "${ipaddrs[1]}",
        "mac": "${macaddrs[1]}",
        "next_hop": {
            "ip": "${nhipaddrs[1]}",
            "mac": "${nhmacaddrs[1]}"
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
    "access_ip": "${nhipaddrs[0]}",
    "enable_p4rt": false
}
EOF
    
    log_success "Configuración BESS Docker generada: ${confpath}/upf.jsonc"
}

# Función principal modificada para Docker
function setup_upf_docker() {
    local mode="${1:-sim}"
    
    log_info "=== CONFIGURACIÓN UPF PARA DOCKER COMPOSE ==="
    
    # Configurar entorno
    setup_docker_environment || {
        log_error "Error configurando entorno Docker"
        return 1
    }
    
    # Configurar BESS
    bessctl_configure_docker "$mode"
    
    # Mostrar resumen
    echo -e "${GREEN}"
    echo "=========================================="
    echo "        CONFIGURACIÓN COMPLETADA"
    echo "=========================================="
    echo -e "${NC}"
    log_success "UPF configurado para Docker Compose"
    log_info "Modo: $mode"
    log_info "Red Docker: $DOCKER_NETWORK"
    log_info "Configuración: ${confpath}/upf.jsonc"
    
    return 0
}

# ================================================
# FUNCIONES ORIGINALES (BARE METAL)
# ================================================
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
HUGEPAGES='-m 2048'
# Use more hugepages for CNDP
if [ "$mode" == 'cndp' ]; then
	HUGEPAGES='-m 2048'
fi

cd ..
cp utilFiles/VERSION .

# ================================================
# FUNCIÓN PRINCIPAL
# ================================================

main() {
    local mode="${1:-sim}"
    
    echo -e "${BLUE}"
    echo "==============================================="
    echo "       INICIANDO CONFIGURACIÓN UPF BESS"
    echo "==============================================="
    echo -e "${NC}"
    
	setup_upf_docker "$mode"
        
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}"
        echo "==============================================="
        echo "     ✓ CONFIGURACIÓN COMPLETADA CON ÉXITO"
        echo "==============================================="
        echo -e "${NC}"
    else
        echo -e "${RED}"
        echo "==============================================="
        echo "     ✗ ERROR EN LA CONFIGURACIÓN"
        echo "==============================================="
        echo -e "${NC}"
    fi
    
    return $exit_code
}

# Ejecutar función principal si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
	--cpuset-cpus=0-1 \
	--ulimit memlock=-1 -v /dev/hugepages:/dev/hugepages \
	-v "$PWD/upf/conf":/opt/bess/bessctl/conf \
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
	-v "$PWD/upf/conf/upf.jsonc":/conf/upf.jsonc \
	upf-epc-pfcpiface:"$(<VERSION)" \
	-config /conf/upf.jsonc

# Don't run any other container if mode is "sim"
if [ "$mode" == 'sim' ]; then
	exit
fi

# Run bess-routectl
docker run --name bess-routectl -td --restart unless-stopped \
	-v "$PWD/upf/conf/route_control.py":/route_control.py \
	--net container:pause --pid container:bess \
	--entrypoint /route_control.py \
	upf-epc-bess:"$(<VERSION)" -i "${ifaces[@]}"
