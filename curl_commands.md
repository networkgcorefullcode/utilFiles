# Comandos Curls

## Check API K4 KEYS webconsole

```sh
# Obtener todas las claves k4
curl -X GET http://192.168.12.16:5000/api/k4opt

# Obtener una clave k4 específica por SNO
curl -X GET http://192.168.12.16:5000/api/k4opt/1

# Crear una nueva clave k4
curl -X POST http://192.168.12.16:5000/api/k4opt \
  -H "Content-Type: application/json" \
  -d '{
    "k4": "abc123def456",
    "k4_sno": 1
  }'

curl -X POST http://192.168.12.16:30001/api/k4opt \
  -H "Content-Type: application/json" \
  -d '{
    "k4": "1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF",
    "k4_sno": 1
  }'

# Actualizar una clave k4
curl -X PUT http://192.168.12.16:5000/api/k4opt/1 \
  -H "Content-Type: application/json" \
  -d '{
    "k4": "xyz789def456",
    "k4_sno": 1
  }'

# Eliminar una clave k4
curl -X DELETE http://192.168.12.16:5000/api/k4opt/1
```

```powershell
# Obtener todas las claves k4
Invoke-RestMethod -Method Get -Uri "http://192.168.12.16:5000/api/k4opt"

# Obtener una clave k4 específica por SNO
Invoke-RestMethod -Method Get -Uri "http://192.168.12.16:5000/api/k4opt/1"

# Crear una nueva clave k4
Invoke-RestMethod -Method Post -Uri "http://192.168.12.16:5000/api/k4opt" `
    -ContentType "application/json" `
    -Body '{"k4": "abc123def456", "k4_sno": 1}'

# Actualizar una clave k4
Invoke-RestMethod -Method Put -Uri "http://192.168.12.16:5000/api/k4opt/1" `
    -ContentType "application/json" `
    -Body '{"k4": "xyz789def456", "k4_sno": 1}'

# Eliminar una clave k4
Invoke-RestMethod -Method Delete -Uri "http://192.168.12.16:5000/api/k4opt/1"
```

```bash
# Crear un nuevo suscriptor con datos de autenticacion
curl -X POST http://192.168.12.16:5000/api/subscriber/<ueId_IMSI> \
  -H "Content-Type: application/json" \
  -d '{
    "plmnID": "12345",
    "opc": "abc123",
    "key": "def456",
    "sequenceNumber": "1",
    "k4_sno": 1,
    "encryptionAlgorithm": 1
  }'

curl -X POST http://192.168.12.16:30001/api/subscriber/imsi-208930100007595 \
  -H "Content-Type: application/json" \
  -d '{
    "plmnID": "20893",
    "opc": "981d464c7c52eb6e5036234984ad0bcf",
    "key": "DC1D1221FA595EBE23E93399D48CBEBF",
    "sequenceNumber": "16f3b3f70fc2",
    "k4_sno": 1,
    "encryptionAlgorithm": 1
  }'
```
