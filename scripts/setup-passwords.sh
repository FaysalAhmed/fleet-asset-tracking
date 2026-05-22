#!/usr/bin/env bash
# Setup MQTT broker credentials
# Usage: ./scripts/setup-passwords.sh

set -euo pipefail

MOSQUITTO_IMAGE="${1:-eclipse-mosquitto:2}"
CONFIG_DIR="$(pwd)/mosquitto/config"
PASSWD_FILE="${CONFIG_DIR}/passwords.txt"

echo "=== MQTT Broker Credential Setup ==="
echo "Mosquitto image: ${MOSQUITTO_IMAGE}"
echo "Config directory: ${CONFIG_DIR}"
echo ""

rm -f "${PASSWD_FILE}"
touch "${PASSWD_FILE}"

declare -A USERS
USERS["bridge"]="bridge123"
USERS["gateway"]="gateway123"
USERS["admin"]="admin123"

for user in "${!USERS[@]}"; do
  pass="${USERS[$user]}"
  echo "  Adding user: ${user}"
  docker run --rm -v "${CONFIG_DIR}:/mosquitto/config" \
    "${MOSQUITTO_IMAGE}" \
    mosquitto_passwd -b /mosquitto/config/passwords.txt "${user}" "${pass}"
done

echo ""
echo "Password file created at: ${PASSWD_FILE}"
echo "Users: ${!USERS[*]}"
