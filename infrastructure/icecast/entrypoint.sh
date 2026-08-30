#!/usr/bin/env bash
set -euo pipefail
umask 077
mkdir -p /var/log/icecast2
chown nobody:nogroup /var/log/icecast2
config_path="$(mktemp /tmp/tarteel-icecast.XXXXXX.xml)"
trap 'rm -f "$config_path"' EXIT
node /opt/tarteel/render-config.mjs /opt/tarteel/icecast.xml.template "$config_path"
exec icecast2 -c "$config_path"
