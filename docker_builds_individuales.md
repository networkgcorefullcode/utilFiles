# Comandos Docker Build para Servicios Individuales

Este documento proporciona los comandos `docker build` equivalentes para construir cada imagen definida en el `docker-compose.yml` de este proyecto, permitiendo construir cada imagen de forma individual.

---

## Comandos de build

### amf

```sh
docker build -t amf ./amf
```

### ausf

```sh
docker build -t ausf ./ausf
```

### nrf

```sh
docker build -t nrf ./nrf
```

### nssf

```sh
docker build -t nssf ./nssf
```

### pcf

```sh
docker build -t pcf ./pcf
```

### smf

```sh
docker build -t smf ./smf
```

### udm

```sh
docker build -t udm ./udm
```

### udr

```sh
docker build -t udr ./udr
```

### webui (webconsole)

```sh
docker build -t webconsole ./webconsole
```

---

> **Nota:** Los servicios `nettools` y `mongodb` usan imágenes públicas de Docker Hub y no requieren build manual.

> Si necesitas construir el servicio `upf`, descomenta y usa:

> ```sh
> docker build -t upf ./upf
> ```
