#!/bin/sh
set -eu

URL="${URL:?set URL}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-10}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-5}"
MAX_REDIRS="${MAX_REDIRS:-10}"

# Choose ONE targeting mode:
#  - TARGET_CONTAINERS: space-separated container names/ids
#  - TARGET_LABEL: docker label filter, e.g. com.example.urlguard=headscale-stack
TARGET_CONTAINERS="${TARGET_CONTAINERS:-}"
TARGET_LABEL="${TARGET_LABEL:-}"

check_url() {
  code="$(curl -sS -o /dev/null -w '%{http_code}' \
    --head --location --max-redirs "$MAX_REDIRS" \
    --connect-timeout "$TIMEOUT_SECONDS" --max-time "$TIMEOUT_SECONDS" \
    "$URL" || echo 000)"
  [ "$code" = "200" ]
}

list_targets() {
  if [ -n "$TARGET_CONTAINERS" ]; then
    printf '%s\n' "$TARGET_CONTAINERS"
    return 0
  fi

  if [ -n "$TARGET_LABEL" ]; then
    # -a includes stopped containers too
    docker ps -aq --filter "label=$TARGET_LABEL"
    return 0
  fi

  echo "ERROR: set TARGET_CONTAINERS or TARGET_LABEL" >&2
  return 1
}

restart_targets() {
  targets="$(list_targets)"
  if [ -z "$targets" ]; then
    echo "$(date -Iseconds) No matching containers to restart."
    return 0
  fi

  # Intentional word-splitting into args
  set -- $targets

  for c in "$@"; do
    docker restart "$c" >/dev/null 2>&1 || docker start "$c" >/dev/null 2>&1 || true
  done
}

# Allow use as a Docker healthcheck
if [ "${1:-}" = "check" ]; then
  check_url
  exit $?
fi

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
      echo "$(date -Iseconds) URL is unreachable -> will restart on recovery"
    fi
    state="down"
  fi

  sleep "$INTERVAL_SECONDS"
done
