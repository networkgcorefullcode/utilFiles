#!/bin/bash

# Script para generar CA propia y certificados firmados para servicios 5G
CERTS_DIR="./certs"
VALIDITY_DAYS=365
CA_VALIDITY_DAYS=3650

# Lista de servicios 5G
SERVICES=("amf" "ausf" "nrf" "nssf" "pcf" "smf" "udm" "udr" "webui" "mongodb")

echo "🔐 Generando CA propia y certificados firmados para servicios 5G..."

# Crear directorio de certificados si no existe
mkdir -p "$CERTS_DIR"

# 1. Generar clave privada de la CA
echo "📋 Generando clave privada de la CA..."
openssl genrsa -out "$CERTS_DIR/ca.key" 4096

# 2. Generar certificado de la CA
echo "📋 Generando certificado de la CA..."
openssl req -new -x509 -days $CA_VALIDITY_DAYS -key "$CERTS_DIR/ca.key" -out "$CERTS_DIR/ca.crt" \
    -subj "/CN=5G Core CA/O=5G Core Network/OU=Certificate Authority/C=US"

# 3. Generar certificados para cada servicio firmados por la CA
for service in "${SERVICES[@]}"; do
    echo "📄 Generando certificado firmado para $service..."
    
    # Crear archivo de configuración con SAN
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
EOF

    # Generar clave privada del servicio
    openssl genrsa -out "$CERTS_DIR/${service}.key" 2048
    
    # Generar CSR (Certificate Signing Request)
    openssl req -new -key "$CERTS_DIR/${service}.key" -out "$CERTS_DIR/${service}.csr" \
        -config "$CERTS_DIR/${service}.conf"
    
    # Firmar el certificado con la CA
    openssl x509 -req -in "$CERTS_DIR/${service}.csr" -CA "$CERTS_DIR/ca.crt" -CAkey "$CERTS_DIR/ca.key" \
        -CAcreateserial -out "$CERTS_DIR/${service}.crt" -days $VALIDITY_DAYS \
        -extensions v3_req -extfile "$CERTS_DIR/${service}.conf"
    
    # Limpiar archivos temporales
    rm "$CERTS_DIR/${service}.csr" "$CERTS_DIR/${service}.conf"
    
    echo "✓ Certificado firmado generado para $service"
done

# 4. Generar certificado genérico también firmado por la CA
echo "📄 Generando certificado genérico firmado..."
cat > "$CERTS_DIR/tls.conf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = 5g-core-generic
O = 5G Core Network
OU = Generic Certificate
C = US

[v3_req]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = *.net5g
DNS.3 = *.docker.internal
IP.1 = 127.0.0.1
EOF

openssl genrsa -out "$CERTS_DIR/tls.key" 2048
openssl req -new -key "$CERTS_DIR/tls.key" -out "$CERTS_DIR/tls.csr" -config "$CERTS_DIR/tls.conf"
openssl x509 -req -in "$CERTS_DIR/tls.csr" -CA "$CERTS_DIR/ca.crt" -CAkey "$CERTS_DIR/ca.key" \
    -CAcreateserial -out "$CERTS_DIR/tls.crt" -days $VALIDITY_DAYS \
    -extensions v3_req -extfile "$CERTS_DIR/tls.conf"

rm "$CERTS_DIR/tls.csr" "$CERTS_DIR/tls.conf"

echo "🎉 ¡Certificados CA y firmados generados exitosamente!"
echo "📁 Archivos generados en $CERTS_DIR:"
echo "   - ca.crt (Certificado de la CA - debe ser confiado por todos los servicios)"
echo "   - ca.key (Clave privada de la CA)"
echo "   - {servicio}.crt/.key (Certificados firmados para cada servicio)"

echo ""
echo "📋 Próximo paso: Actualizar Docker Compose para montar ca.crt en todos los contenedores"