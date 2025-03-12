# qBittorrent Port forwarding updater 

## Installation
1. Get the script and make it executable
```bash
wget https://raw.githubusercontent.com/Julien9969/qbittorrent-gluetun-auto-portforwarding/refs/heads/main/qbit-port-updater.sh
chmod +x qbit-port-updater.sh
```
2. Edit Gluetun and qbittorrent container
```yaml
services:
  gluetun:
    container_name: gluetun
    image: qmcgaw/gluetun:latest
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - # ports
    environment:
      - # your environment variables
      # Add and fill these environment variables
      - VPN_PORT_FORWARDING_UP_COMMAND=/bin/sh -c "sh qbit-port-updater.sh -p {{PORTS}}"
      - QBIT_HOST=localhost # Default: localhost
      - QBIT_PORT=8095 # Default: 8080
      - QBIT_USER=admin
      - QBIT_PASSWORD=123456
    volumes:
      # add the script to the container
      - ./qbit-port-updater.sh:/qbit-port-updater.sh

  qbittorrent:
    container_name: qbittorrent
    image: linuxserver/qbittorrent:latest
    # qBittorrent configuration
    depends_on:
      - gluetun

```

## Manual execution
```bash
port=$(docker exec -it gluetun sh -c "cat /tmp/gluetun/forwarded_port")
docker exec -it gluetun sh -c "./qbit-port-updater.sh -p $port"
```
