
# Script para registrar/actualizar una instancia NF en NRF usando curl y un JSON externo
#
# Uso:
#   ./Nnrf_NFManagement_Register_NEW_Instance.sh <URL_base> <nfInstanceID>
#
# Ejemplo:
#   ./Nnrf_NFManagement_Register_NEW_Instance.sh https://mi-nrf.local:29510/nnrf-nfm/v1/nf-instances 3fa85f64-5717-4562-b3fc-2c963f66afa6

URL_BASE=${1:-"https://example.com/nnrf-nfm/v1/nf-instances"}

curl -k -X GET "${URL_BASE}/"