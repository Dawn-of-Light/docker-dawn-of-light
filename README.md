# Dawn Of Light Docker Image
Docker Image for Dawn of Light Server

[![Build status](https://img.shields.io/docker/build/dawnoflight/dolsharp.svg)](https://hub.docker.com/r/dawnoflight/dolsharp/)
[![Image Size](https://img.shields.io/microbadger/image-size/dawnoflight/dolsharp:sandbox.svg)](https://microbadger.com/images/dawnoflight/dolsharp:sandbox)
[![Layers](https://img.shields.io/microbadger/layers/dawnoflight/dolsharp:sandbox.svg)](https://microbadger.com/images/dawnoflight/dolsharp:sandbox)

# Docker Compose

```
version: '2'
services:
  dawn-of-light-sandbox:
    image: dawn-of-light/dolsharp:sandbox
    container_name: dol-sandbox-container
    restart: always
    mem_limit: 2048M
    stop_grace_period: 35s
    environment:
      DOL_MEMORY_LIMIT: 2147483648
      DOL_CPU_USE: 2
      DOL_SERVER_NAME: Admin Sandbox
      DOL_SERVER_NAMESHORT: ADMSANDBOX
      DOL_SANDBOX_SERVERUPDATE_USERNAME: Your_ServerListUpdate_Username
      DOL_SANDBOX_SERVERUPDATE_PASSWORD: Your_ServerListUpdate_Password
    ports:
     - 10300:10300/tcp
     - 10400:10400/udp
    tmpfs:
     - /dawn-of-light/database
     - /dawn-of-light/logs
```
