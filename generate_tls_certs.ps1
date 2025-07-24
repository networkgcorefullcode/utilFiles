# Script de PowerShell para generar certificados TLS con nombres DNS correctos para contenedores
# Requiere OpenSSL instalado o se puede usar con Git Bash

$CERTS_DIR = "./certs"
$VALIDITY_DAYS = 365

# Lista de servicios con sus nombres DNS
$SERVICES = @{
    "amf" = @("amf", "amf.net5g", "localhost", "127.0.0.1")
    "ausf" = @("ausf", "ausf.net5g", "localhost", "127.0.0.1") 
    "nrf" = @("nrf", "nrf.net5g", "localhost", "127.0.0.1")
    "nssf" = @("nssf", "nssf.net5g", "localhost", "127.0.0.1")
    "pcf" = @("pcf", "pcf.net5g", "localhost", "127.0.0.1")
    "smf" = @("smf", "smf.net5g", "localhost", "127.0.0.1")
    "udm" = @("udm", "udm.net5g", "localhost", "127.0.0.1")
    "udr" = @("udr", "udr.net5g", "localhost", "127.0.0.1")
    "webui" = @("webui", "webui.net5g", "localhost", "127.0.0.1")
    "mongodb" = @("mongodb", "mongodb.net5g", "localhost", "127.0.0.1")
}

Write-Host "🔐 Generando certificados TLS para servicios 5G..." -ForegroundColor Green

# Crear directorio si no existe
if (!(Test-Path $CERTS_DIR)) {
    New-Item -ItemType Directory -Path $CERTS_DIR
}

# Función para crear certificado
function New-ServiceCertificate {
    param(
        [string]$ServiceName,
        [string[]]$DnsNames
    )
    
    Write-Host "📄 Generando certificado para $ServiceName..." -ForegroundColor Yellow
    
    # Crear archivo de configuración temporal
    $configFile = "$CERTS_DIR/$ServiceName.conf"
    $dnsSection = ""
    for ($i = 0; $i -lt $DnsNames.Count; $i++) {
        $dnsSection += "DNS.$($i+1) = $($DnsNames[$i])`n"
    }
    
    $configContent = @"
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $ServiceName
O = 5G Core Network
OU = Network Function $($ServiceName.ToUpper())
C = US
ST = Docker
L = Container

[v3_req]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
$dnsSection
IP.1 = 127.0.0.1
IP.2 = ::1
"@
    
    $configContent | Out-File -FilePath $configFile -Encoding UTF8
    
    # Comandos usando openssl (requiere tener openssl en PATH o Git Bash)
    $keyFile = "$CERTS_DIR/$ServiceName.key"
    $certFile = "$CERTS_DIR/$ServiceName.crt"
    
    # Generar clave privada
    & openssl genrsa -out $keyFile 2048
    
    # Generar certificado
    & openssl req -new -x509 -key $keyFile -out $certFile -days $VALIDITY_DAYS -config $configFile -extensions v3_req
    
    # Limpiar archivo temporal
    Remove-Item $configFile
    
    Write-Host "  ✓ Certificado generado: $ServiceName.crt / $ServiceName.key" -ForegroundColor Green
}

# Generar certificados para cada servicio
foreach ($service in $SERVICES.Keys) {
    New-ServiceCertificate -ServiceName $service -DnsNames $SERVICES[$service]
}

# Generar certificado genérico
Write-Host "📄 Generando certificado genérico..." -ForegroundColor Yellow
$genericConfig = @"
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
"@

$genericConfig | Out-File -FilePath "$CERTS_DIR/generic.conf" -Encoding UTF8
& openssl genrsa -out "$CERTS_DIR/tls.key" 2048
& openssl req -new -x509 -key "$CERTS_DIR/tls.key" -out "$CERTS_DIR/tls.crt" -days $VALIDITY_DAYS -config "$CERTS_DIR/generic.conf" -extensions v3_req
Remove-Item "$CERTS_DIR/generic.conf"

Write-Host ""
Write-Host "🔐 Certificados TLS generados exitosamente!" -ForegroundColor Green
Write-Host "📋 Resumen de certificados:" -ForegroundColor Cyan
foreach ($service in $SERVICES.Keys) {
    Write-Host "  - $service`: $service.crt / $service.key (incluye: $($SERVICES[$service] -join ', '))" -ForegroundColor White
}
Write-Host "  - genérico: tls.crt / tls.key" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Los certificados ahora incluyen los nombres DNS correctos para contenedores!" -ForegroundColor Green
