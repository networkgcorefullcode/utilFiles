# Comandos Docker para Servicios Individuales

Este documento proporciona los comandos `docker run` equivalentes para ejecutar cada servicio definido en el `docker-compose.yml` de este proyecto, permitiendo iniciar cada contenedor de forma individual.

> **Nota:** Asegúrate de tener las imágenes construidas previamente (`docker build`) si el servicio requiere `build:` en lugar de `image:`.

---

## Red personalizada
Primero, crea la red si no existe:
```sh
docker network create --subnet=172.28.0.0/16 net5g
```

---

## Servicios

### amf

```sh
docker run -d --name amf \
  --network net5g --ip 172.28.0.2 \
  -p 8001:8000 \
  -v $(pwd)/configs_files/docker_compose_config/amfcfg.yaml:/app/config.yaml \
  amf \
  /usr/local/bin/amf --cfg /app/config.yaml
```

### ausf

```sh
docker run -d --name ausf \
  --network net5g --ip 172.28.0.3 \
  -p 8002:8000 \
  -v $(pwd)/configs_files/docker_compose_config/ausfcfg.yaml:/app/config.yaml \
  ausf \
  /usr/local/bin/ausf --cfg /app/config.yaml
```

### nrf

```sh
docker run -d --name nrf \
  --network net5g --ip 172.28.0.4 \
  -p 8003:8000 \
  -v $(pwd)/configs_files/docker_compose_config/nrfcfg.yaml:/app/config.yaml \
  nrf \
  /usr/local/bin/nrf --cfg /app/config.yaml
```

### nssf

```sh
docker run -d --name nssf \
  --network net5g --ip 172.28.0.5 \
  -p 8004:8000 \
  -v $(pwd)/configs_files/docker_compose_config/test_nssf_config.yaml:/app/config.yaml \
  nssf \
  /usr/local/bin/nssf --cfg /app/config.yaml
```

### pcf

```sh
docker run -d --name pcf \
  --network net5g --ip 172.28.0.6 \
  -p 8005:8000 \
  -v $(pwd)/configs_files/docker_compose_config/pcfcfg.yaml:/app/config.yaml \
  pcf \
  /usr/local/bin/pcf --cfg /app/config.yaml
```

### smf

```sh
docker run -d --name smf \
  --network net5g --ip 172.28.0.7 \
  -p 8006:8000 \
  -v $(pwd)/configs_files/docker_compose_config/smfcfg.yaml:/app/config.yaml \
  smf \
  /usr/local/bin/smf --cfg /app/config.yaml
```

### udm

```sh
docker run -d --name udm \
  --network net5g --ip 172.28.0.8 \
  -p 8007:8000 \
  -v $(pwd)/configs_files/docker_compose_config/udmcfg.yaml:/app/config.yaml \
  udm \
  /usr/local/bin/udm --cfg /app/config.yaml
```

### udr

```sh
docker run -d --name udr \
  --network net5g --ip 172.28.0.9 \
  -p 8008:8000 \
  -v $(pwd)/configs_files/docker_compose_config/udr_config.yaml:/app/config.yaml \
  udr \
  /usr/local/bin/udr --cfg /app/config.yaml
```

### webui

```sh
docker run -d --name webui \
  --network net5g --ip 172.28.0.11 \
  -p 8009:8000 \
  -v $(pwd)/configs_files/docker_compose_config/webuicfg.yaml:/app/config.yaml \
  webconsole \
  /usr/local/bin/webconsole --cfg /app/config.yaml
```

### nettools
```sh
docker run -d --name nettools \
  --network net5g --ip 172.28.0.20 \
  nicolaka/netshoot:latest
```

### mongodb

```sh
docker run -d --name mongodb \
  --network net5g --ip 172.28.0.30 \
  -p 27017:27017 \
  -v $(pwd)/mongo_data:/data/db \
  --restart unless-stopped \
  mongo:latest
```

---

> **Recuerda:**
> - Cambia `$(pwd)` por la ruta absoluta si usas PowerShell o CMD en Windows, o usa `${PWD}` en PowerShell.
> - Si la imagen no existe, primero constrúyela con `docker build -t <nombre> <directorio>`.
> - Los servicios comentados en el compose (como `upf`) no están incluidos aquí.
