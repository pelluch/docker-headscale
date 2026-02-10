#!/bin/sh
#
# url-guard — monitors a URL and restarts Docker containers when it recovers.
#
# Useful for services that depend on an external endpoint (e.g. an OIDC
# provider): when the endpoint goes down the dependent services often need
# a restart once it comes back.
#
# Supports two targeting modes (set exactly one):
#   TARGET_CONTAINERS  space-separated container names or IDs
#   TARGET_LABEL       docker label filter (e.g. com.example.urlguard=stack)
#
# Pass "check" as the first argument to run a single probe and exit — this
# is intended for use as a Docker HEALTHCHECK command.
set -eu

URL="${URL:?set URL}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-10}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-5}"
MAX_REDIRS="${MAX_REDIRS:-10}"

TARGET_CONTAINERS="${TARGET_CONTAINERS:-}"
TARGET_LABEL="${TARGET_LABEL:-}"

# Probe $URL with a HEAD request and succeed only on HTTP 200.
# Stores the status code in $last_code for logging on failure.
last_code=""
check_url() {
  last_code="$(curl -sS -o /dev/null -w '%{http_code}' \
    --head --location --max-redirs "$MAX_REDIRS" \
    --connect-timeout "$TIMEOUT_SECONDS" --max-time "$TIMEOUT_SECONDS" \
    "$URL" || echo 000)"
  [ "$last_code" = "200" ]
}

# Print the list of containers that should be restarted.
list_targets() {
  if [ -n "$TARGET_CONTAINERS" ]; then
    printf '%s\n' "$TARGET_CONTAINERS"
    return 0
  fi

  if [ -n "$TARGET_LABEL" ]; then
    docker ps -aq --filter "label=$TARGET_LABEL"
    return 0
  fi

  echo "ERROR: set TARGET_CONTAINERS or TARGET_LABEL" >&2
  return 1
}

# Restart (or start) every target container.
restart_targets() {
  targets="$(list_targets)"
  if [ -z "$targets" ]; then
    echo "$(date -Iseconds) No matching containers to restart."
    return 0
  fi

  # Word-split $targets so each name becomes a separate argument.
  set -- $targets

  for c in "$@"; do
    echo "$(date -Iseconds) Restarting $c"
    docker restart "$c" >/dev/null 2>&1 || docker start "$c" >/dev/null 2>&1 || true
  done
}

# --- Healthcheck mode: single probe then exit ---------------------------
if [ "${1:-}" = "check" ]; then
  check_url
  exit $?
fi

# --- Main loop: watch URL and restart targets on recovery ---------------
echo "$(date -Iseconds) url-guard starting — watching $URL every ${INTERVAL_SECONDS}s"

state="unknown"
while true; do
  if check_url; then
    if [ "$state" = "down" ]; then
      echo "$(date -Iseconds) URL is reachable again -> restarting targets"
      restart_targets
    fi
    state="up"
  else
    if [ "$state" != "down" ]; then
      echo "$(date -Iseconds) URL is unreachable (HTTP $last_code) -> will restart on recovery"
    fi
    state="down"
  fi

  sleep "$INTERVAL_SECONDS"
done
