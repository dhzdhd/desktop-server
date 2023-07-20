# desktop-server

The docker compose configuration for the server setup I use in the vmConsole app hosted on my phone.

## Applications used

- Homepage - a dashboard web app
- Portainer - a Docker monitoring service

## Setup

- Homepage
  - Follow [gist](https://gist.github.com/styblope/dc55e0ad2a9848f2cc3307d4819d819f)
- SWAG (after initial run)
  - Before inital run
    - Add duckdns key to `swag_config\dns-conf\duckdns.ini`
  - After inital run (activate implies remove `.sample`)
    - Activate `swag_config\nginx\proxy-confs\portainer.subdomain.conf`
