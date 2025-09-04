#!/bin/bash

echo "Waiting for MongoDB to start..."
sleep 10

echo "Initiating replica set..."
mongosh --host mongodb:27017 --eval "
rs.initiate({
  _id: 'rs0',
  members: [
    { _id: 0, host: "mongodb:27017" },
    { _id: 1, host: "mongo2:27017" },
    { _id: 2, host: "mongo3:27017" }
  ]
});

// Wait for replica set to be ready
while(rs.status().myState != 1) {
  print('Waiting for replica set to be ready...');
  sleep(1000);
}

print('Replica set initialized successfully!');
"

echo "MongoDB replica set setup completed!"
