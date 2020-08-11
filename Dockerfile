FROM alpine:latest

RUN apk add --no-cache \
	bash \
	tinyproxy \
	openvpn

COPY run.sh /opt/docker-openvpn-proxy/run.sh

ENTRYPOINT ["/opt/docker-openvpn-proxy/run.sh"]
