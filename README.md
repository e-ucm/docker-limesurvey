# docker-limesurvey
A docker image to deploy LimeSurvey https://github.com/LimeSurvey/LimeSurvey

## Development setup

The script `setup-dev.sh` takes care of preparing the project for development and to launch all containers.

### DNS resolution

To reach the containers from the host you new to setup the DNS resolution. You have two options:
1. Change `/etc/hosts`
2. Use `127.1.1.1` as DNS server

#### `/etc/hosts` configuration

You have to add the following entries to the `/etc/hosts` file:
```
127.0.0.1	traefik.external.test
127.0.0.1	sso.external.test
127.0.0.1	limesurvey.external.test
127.0.0.1	mail.external.test
127.0.0.1	whoami.external.test
127.0.0.1	phpmyadmin.external.test
```
> Note: if you change the `EXTERNAL_DOMAIN` environment variable, you have to change the previous entries appropriately.

#### Use `127.1.1.1` as DNS server

As part of the `docker-compose.yml` there is an instance of CoreDNS that you can use to resolve all containers. In addition, the container is configured to forward other / external DNS resolution to proper DNS servers. By default this container can be reached at `127.1.1.1`, so you can use it as DNS server.

By default external DNS resolution are forwarded to Google's DNS servers (e.g. 8.8.8.8, 8.8.4.4) unless you configure `DNS_SERVERS` environment variable.

### SSL certificate for development

The `docker-compose.yml` depends on a ssl certificate. Unfortunately we can not use LetsEncrypt for development, so it is needed to create a self-signed certificate for Traefik. Moreover it is needed to install that self-signed certificate inside the browsers certificate manager or the OS certificate manager.

Instead generating and configure the certificate manually using [openssl](https://www.openssl.org/), [EasyRSA](https://github.com/OpenVPN/easy-rsa) or [cfssl](https://github.com/cloudflare/cfssl), you can use [mkcert](https://github.com/FiloSottile/mkcert).

As part of the setup process, the `traefik` container generates an `mkcert` CA and generates certificates for all other containers. If you want to avoid your browser error about the unrecognized CA, you have to import the CA cert `./data/traefik/ssl/ca/rootCA.pem`.