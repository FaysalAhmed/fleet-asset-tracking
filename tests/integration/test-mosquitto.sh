#!/usr/bin/env bash
# Integration tests for Mosquitto MQTT broker
# Requires: broker running via `docker compose up -d`

set -euo pipefail

COMPOSE="docker compose"
BROKER="fleet-mqtt-broker"
ADMIN="-u admin -P admin123"
PASSED=0
FAILED=0

pass()  { PASSED=$((PASSED+1)); echo "  PASS  $1"; }
fail()  { FAILED=$((FAILED+1)); echo "  FAIL  $1"; }

echo "=== Mosquitto Integration Tests ==="
echo ""

# 1. Container health
echo "--- Connectivity ---"
if docker compose ps --status running --format json "$BROKER" 2>/dev/null | grep -q running; then
  pass "Broker container is running"
else
  fail "Broker container is not running"
fi

UPTIME=$($COMPOSE exec "$BROKER" mosquitto_sub -t '$SYS/broker/uptime' -C 1 $ADMIN 2>/dev/null)
if [ -n "$UPTIME" ]; then
  pass "Healthcheck via \$SYS/broker/uptime (uptime: ${UPTIME}s)"
else
  fail "No response from \$SYS/broker/uptime"
fi

# 2. Publish / Subscribe
echo "--- Pub/Sub ---"
TOPIC="fleet/test-001/telemetry"
PAYLOAD='{"lat":23.8,"lng":90.4,"speed":45}'
$COMPOSE exec "$BROKER" mosquitto_pub -t "$TOPIC" -m "$PAYLOAD" $ADMIN 2>/dev/null
RECEIVED=$($COMPOSE exec "$BROKER" mosquitto_sub -t "$TOPIC" -C 1 $ADMIN 2>/dev/null)
if [ "$RECEIVED" = "$PAYLOAD" ]; then
  pass "Publish and subscribe to telemetry topic"
else
  fail "Expected '$PAYLOAD', got '$RECEIVED'"
fi

# 3. Retained messages
echo "--- Retained Messages ---"
TOPIC="fleet/test-retain/telemetry"
PAYLOAD='{"lat":23.9,"lng":90.5,"status":"retained"}'
$COMPOSE exec "$BROKER" mosquitto_pub -t "$TOPIC" -m "$PAYLOAD" -r $ADMIN 2>/dev/null
sleep 1
RECEIVED=$($COMPOSE exec "$BROKER" mosquitto_sub -t "$TOPIC" -C 1 $ADMIN 2>/dev/null)
if [ "$RECEIVED" = "$PAYLOAD" ]; then
  pass "Retained message persists after publish"
else
  fail "Expected '$PAYLOAD', got '$RECEIVED'"
fi

# 4. Broker info
echo "--- Broker Info ---"
CLIENTS=$($COMPOSE exec "$BROKER" mosquitto_sub -t '$SYS/broker/clients/connected' -C 1 $ADMIN 2>/dev/null)
if [ -n "$CLIENTS" ] && [ "$CLIENTS" -ge 0 ] 2>/dev/null; then
  pass "Broker reports connected clients ($CLIENTS)"
else
  fail "Expected client count, got '$CLIENTS'"
fi

echo ""
echo "=== Results ==="
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"
echo "  Total:  $((PASSED+FAILED))"

[ "$FAILED" -eq 0 ]
