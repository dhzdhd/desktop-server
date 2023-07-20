# desktop-server

The docker compose configuration for the server setup I use in my desktop/server/laptop/Raspberry Pi

## Applications used

- Homepage - a dashboard web app
- Portainer - a Docker monitoring service

## Setup

- Homepage
  - Follow [gist](https://gist.github.com/styblope/dc55e0ad2a9848f2cc3307d4819d819f)
- SWAG (after initial run)
  - Before initial run
    - Add duckdns key to `swag_config\dns-conf\duckdns.ini`
  - After inital run (activate implies remove `.sample`)
    - Move `www.subdomain.conf` to `swag_config\nginx\proxy-confs\`
    - Activate `swag_config\nginx\proxy-confs\portainer.subdomain.conf`
