// Este archivo se ejecuta automáticamente al inicializar MongoDB
print('MongoDB initialization script running...');

// Crear la base de datos webuiDB y sus colecciones
db = db.getSiblingDB('webuiDB');
db.createCollection('users');
db.createCollection('sessions');

print('Created webuiDB database with collections');

// Crear base de datos de autenticación
db = db.getSiblingDB('authdb');
db.createCollection('authKeys');

print('Created authdb database with authKeys collection');

print('MongoDB initialization completed!');
