# Headscale + Headplane Stack

> Note: I used Claude to generate this README and facilitate the creation of url-guard.sh. I am a software engineer and have reviewed all changes, however.

Docker Compose stack running [Headscale](https://github.com/juanfont/headscale) (self-hosted Tailscale control server) with [Headplane](https://github.com/tale/headplane) (web UI) and a URL monitoring sidecar.

## Services

- **headscale** — coordination server for the WireGuard mesh
- **headplane** — web management UI, connects to headscale's API and config
- **url-guard** — monitors an external URL (e.g. an OIDC provider) and restarts headscale and headplane when it recovers from an outage

## Setup

1. Copy the environment template and fill it in:

   ```sh
   cp .env.template .env
   ```

2. Configure the `.env` file:

   | Variable | Required | Description |
   |---|---|---|
   | `TZ` | no | Timezone (e.g. `America/New_York`) |
   | `HEADSCALE_EXTERNAL_PORT` | yes | Host port for headscale (maps to 8080) |
   | `HEADPLANE_EXTERNAL_PORT` | yes | Host port for headplane (maps to 3000) |
   | `OIDC_URL` | yes | OIDC endpoint URL to monitor (e.g. your discovery endpoint) |
   | `OIDC_URL_INTERVAL` | no | Polling interval in seconds (default: 10) |
   | `OIDC_URL_TIMEOUT` | no | Curl timeout in seconds (default: 5) |
   | `OIDC_URL_MAX_REDIRS` | no | Max redirects to follow (default: 10) |

3. Place your configuration files:

   - `headscale/config/` — headscale configuration (including `config.yaml`)
   - `headplane/config/config.yaml` — headplane configuration

4. Start the stack:

   ```sh
   docker compose up -d
   ```

## How url-guard works

url-guard polls the configured URL and tracks whether it's reachable (HTTP 200). When the URL recovers after being down, it restarts headscale and headplane so they can re-establish connections (e.g. to an OIDC provider).

Behavior on startup depends on the `depends_on` conditions in `compose.yaml`. As currently configured, headscale and headplane wait for url-guard's healthcheck to pass before starting — meaning the URL must be reachable for the stack to come up.

To allow the stack to start regardless of URL availability (and restart containers only once the URL becomes reachable), change the url-guard dependency from `condition: service_healthy` to `condition: service_started`.

## Directory structure

```
.
├── compose.yaml
├── .env.template
├── headscale/
│   ├── config/          # headscale config (mounted into container)
│   └── lib/headscale/   # headscale data
├── headplane/
│   ├── config/          # headplane config
│   └── data/            # headplane data
└── url-guard/
    ├── Dockerfile
    └── url-guard.sh
```
