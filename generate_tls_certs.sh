#!/bin/bash

# Script para generar certificados TLS autofirmados para cada servicio 5G
# Cada servicio tendrá su propio certificado con el nombre del servicio como CN

CERTS_DIR="./certs"
VALIDITY_DAYS=365

# Lista de servicios 5G
SERVICES=("amf" "ausf" "nrf" "nssf" "pcf" "smf" "udm" "udr" "webui" "mongodb")

echo "Generando certificados TLS autofirmados para servicios 5G..."

# Crear directorio de certificados si no existe
mkdir -p "$CERTS_DIR"

# Generar certificados para cada servicio
for service in "${SERVICES[@]}"; do
    echo "Generando certificado para $service..."
    
    # Generar clave privada y certificado en un solo comando
    openssl req -x509 -newkey rsa:2048 \
        -keyout "$CERTS_DIR/${service}.key" \
        -out "$CERTS_DIR/${service}.crt" \
        -days $VALIDITY_DAYS \
        -nodes \
        -subj "/CN=${service}/O=5G Core Network/OU=Network Functions/C=US" \
        -addext "subjectAltName=DNS:${service},DNS:localhost,IP:127.0.0.1"
    
    echo "✓ Certificado generado para $service"
done

# Generar certificado genérico para compatibilidad (por si algún servicio aún usa tls.crt/tls.key)
echo "Generando certificado genérico..."
openssl req -x509 -newkey rsa:2048 \
    -keyout "$CERTS_DIR/tls.key" \
    -out "$CERTS_DIR/tls.crt" \
    -days $VALIDITY_DAYS \
    -nodes \
    -subj "/CN=5g-core/O=5G Core Network/OU=Generic/C=US" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

echo "✓ Certificado genérico generado"

# Establecer permisos apropiados
chmod 644 "$CERTS_DIR"/*.crt
chmod 600 "$CERTS_DIR"/*.key

echo ""
echo "🔐 Certificados TLS generados exitosamente:"
ls -la "$CERTS_DIR"

echo ""
echo "📋 Resumen de certificados:"
for service in "${SERVICES[@]}"; do
    echo "  - $service: ${service}.crt / ${service}.key"
done
echo "  - genérico: tls.crt / tls.key"
