# Comands

Comando para ejecutar mongo-express y que utilice la configuracion de mongo que esta en el localhost

```bash
docker run -d \
  --name mongo-express \
  --network host \
  -e ME_CONFIG_MONGODB_SERVER=127.0.0.1 \
  -e ME_CONFIG_MONGODB_PORT=27017 \
  -e ME_CONFIG_BASICAUTH_USERNAME=admin \
  -e ME_CONFIG_BASICAUTH_PASSWORD=admin123 \
  mongo-express:latest
```

Para mongo db

---

## 🔹 Conexión y bases de datos

```bash
# Mostrar la base de datos actual
db

# Listar todas las bases de datos
show dbs

# Cambiar o crear una base de datos
use miBaseDeDatos
```

---

## 🔹 Colecciones

```bash
# Listar colecciones en la base de datos actual
show collections

# Crear colección
db.createCollection("usuarios")

# Eliminar colección
db.usuarios.drop()
```

---

## 🔹 Insertar documentos

```javascript
# Insertar un documento
db.usuarios.insertOne({ nombre: "Pedro", edad: 25 })

# Insertar múltiples documentos
db.usuarios.insertMany([
  { nombre: "Ana", edad: 22 },
  { nombre: "Luis", edad: 30 }
])
```

---

## 🔹 Consultas básicas

```javascript
# Mostrar todos los documentos
db.usuarios.find()

# Buscar con condición
db.usuarios.find({ edad: 25 })

# Buscar con operadores (mayor que)
db.usuarios.find({ edad: { $gt: 20 } })

# Buscar y formatear salida
db.usuarios.find({}, { nombre: 1, _id: 0 })
```

---

## 🔹 Actualizaciones

```javascript
# Actualizar un campo
db.usuarios.updateOne(
  { nombre: "Pedro" },
  { $set: { edad: 26 } }
)

# Actualizar múltiples documentos
db.usuarios.updateMany(
  { edad: { $lt: 25 } },
  { $set: { activo: true } }
)
```

---

## 🔹 Eliminación

```javascript
# Eliminar un documento
db.usuarios.deleteOne({ nombre: "Ana" })

# Eliminar múltiples documentos
db.usuarios.deleteMany({ edad: { $gt: 40 } })
```

---

## 🔹 Índices

```javascript
# Crear índice
db.usuarios.createIndex({ nombre: 1 })

# Ver índices
db.usuarios.getIndexes()
```

---

## 🔹 Utilidades

```bash
# Contar documentos
db.usuarios.countDocuments()

# Ver tamaño aproximado de la base
db.stats()

# Ver información de la colección
db.usuarios.stats()
```

---

