#!/bin/bash

# Script para generar certificados TLS autofirmados para servicios 5G en contenedores Docker
# Cada servicio tendrá su propio certificado con los nombres DNS correctos en SAN

CERTS_DIR="./certs"
VALIDITY_DAYS=365

# Lista de servicios 5G
SERVICES=("amf" "ausf" "nrf" "nssf" "pcf" "smf" "udm" "udr" "webui" "mongodb")

echo "🔐 Generando certificados TLS con SAN correcto para servicios 5G en contenedores..."

# Crear directorio de certificados si no existe
mkdir -p "$CERTS_DIR"

# Generar certificados para cada servicio
for service in "${SERVICES[@]}"; do
    echo "📄 Generando certificado para $service..."
    
    # Crear archivo de configuración temporal con extensiones SAN
    cat > "$CERTS_DIR/${service}.conf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = ${service}
O = 5G Core Network
OU = Network Function ${service^^}
C = US
ST = Docker
L = Container

[v3_req]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${service}
DNS.2 = ${service}.net5g
DNS.3 = ${service}.docker.internal
DNS.4 = localhost
DNS.5 = ${service}-service
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

    # Generar clave privada
    openssl genrsa -out "$CERTS_DIR/${service}.key" 2048
    
    # Generar certificado usando el archivo de configuración
    openssl req -new -x509 -key "$CERTS_DIR/${service}.key" \
        -out "$CERTS_DIR/${service}.crt" \
        -days $VALIDITY_DAYS \
        -config "$CERTS_DIR/${service}.conf" \
        -extensions v3_req
    
    # Limpiar archivo temporal
    rm "$CERTS_DIR/${service}.conf"
    
    echo "  ✓ Certificado generado con SAN: ${service}, ${service}.net5g, localhost"
done

# Generar certificado genérico para compatibilidad
echo "📄 Generando certificado genérico para compatibilidad..."
cat > "$CERTS_DIR/generic.conf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = 5g-core-generic
O = 5G Core Network
OU = Generic Certificate
C = US
ST = Docker
L = Container

[v3_req]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = *.net5g
DNS.3 = *.docker.internal
DNS.4 = amf
DNS.5 = ausf
DNS.6 = nrf
DNS.7 = nssf
DNS.8 = pcf
DNS.9 = smf
DNS.10 = udm
DNS.11 = udr
DNS.12 = webui
DNS.13 = mongodb
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

openssl genrsa -out "$CERTS_DIR/tls.key" 2048
openssl req -new -x509 -key "$CERTS_DIR/tls.key" \
    -out "$CERTS_DIR/tls.crt" \
    -days $VALIDITY_DAYS \
    -config "$CERTS_DIR/generic.conf" \
    -extensions v3_req

rm "$CERTS_DIR/generic.conf"
echo "  ✓ Certificado genérico generado con wildcards"

# Establecer permisos apropiados
chmod 644 "$CERTS_DIR"/*.crt
chmod 600 "$CERTS_DIR"/*.key

echo ""
echo "🔐 Certificados TLS generados exitosamente:"
ls -la "$CERTS_DIR"

echo ""
echo "📋 Resumen de certificados con SAN correcto:"
for service in "${SERVICES[@]}"; do
    echo "  - $service: ${service}.crt / ${service}.key"
    echo "    SAN: ${service}, ${service}.net5g, ${service}.docker.internal, localhost"
done
echo "  - genérico: tls.crt / tls.key"
echo "    SAN: *.net5g, todos los servicios individuales, localhost"

echo ""
echo "🚀 Certificados listos para Docker Compose!"
echo "   Ahora los servicios pueden conectarse usando nombres de contenedores."
