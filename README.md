# Docker OpenVPN proxy

Use unlimited multiple openvpn connections simultaneously.

Find it on [GitHub](https://github.com/FreeReacts/docker-openvpn-proxy).

Find it on [DockerHub](https://hub.docker.com/repository/docker/freereacts/openvpnproxy).

## Usage
---
### 1. Running a new VPN proxy container

```
Usage:
docker run -d -ti --cap-add=NET_ADMIN --device=/dev/net/tun --name='usavpn' -v "/path/to/vpn.ovpn:/openvpn/config.ovpn" freereacts/openvpnproxy:latest -u username -p mysecurepassword -i 10.1.0.0/24"

[-u username] Username for the VPN connection.
[-p password] Password for the VPN connection.
-i ip_range IP Address/ IP Range of your host network to allow requests.
```

### 2. Get the ip of container

Run `docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' container_name_or_id` on your host PC.
```
$ docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' container_name_or_id
172.16.0.2
```

### 3. Adding the proxy to your browser

Add the result ip address as the proxy ip address and 8888 as the proxy port to your browser.

### Contribute
---
As always, contributions are appriciated. Simply open a Pull request.

