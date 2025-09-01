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