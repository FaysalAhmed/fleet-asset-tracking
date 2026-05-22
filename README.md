# Fleet & Asset Tracking

A real-time fleet tracking platform that ingests GPS/telemetry from IoT devices via MQTT, stores time-series data in InfluxDB, and streams live updates to a web dashboard over WebSockets.

> **Stack:** MQTT · InfluxDB · WebSockets · React  
> **Status:** Active development — Sprint 1 (Core Pipeline)

---

## Quick Start

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

### Start the MQTT Broker

```powershell
docker compose build mosquitto
docker compose up -d mosquitto
```

### Verify It's Running

```powershell
docker compose ps mosquitto
```

Publish a test message:

```powershell
docker compose exec fleet-mqtt-broker mosquitto_pub `
  -t "fleet/v001/telemetry" `
  -m '{"lat":23.8,"lng":90.4,"speed":45}' `
  -u admin -P admin123 -r
```

Subscribe to confirm:

```powershell
docker compose exec fleet-mqtt-broker mosquitto_sub `
  -t "fleet/+/telemetry" -C 1 -u admin -P admin123
```

### Stop

```powershell
docker compose down -v
```

---

## Architecture

```
IoT Device (GPS+CAN) → MQTT Broker → InfluxDB → API Gateway → Web Dashboard
                         ↑                            │
                     Retained messages          WebSocket (JWT)
                     Last-known position        Live updates + alerts
```

### Services

| Service | Technology | Status |
|---------|------------|--------|
| MQTT Broker | Eclipse Mosquitto 2 | ✅ Running |
| MQTT → InfluxDB Bridge | Telegraf / Go | ❌ Sprint 1 |
| Time-Series DB | InfluxDB v3 | ❌ Sprint 1 |
| API Gateway | Go (Gorilla WebSocket) | ❌ Sprint 2 |
| Frontend Dashboard | React + MapLibre | ❌ Sprint 2 |
| Alert Engine | Go / Node.js | ❌ Sprint 3 |

---

## MQTT Topic Design

Each device publishes to a unique topic:

```
fleet/{vehicle_id}/telemetry
```

| User | Role | Access |
|------|------|--------|
| `admin` | Full access | Read/write all topics, `$SYS` |
| `bridge` | Bridge service | Read `fleet/+/telemetry` |
| `gateway` | API Gateway | Read `fleet/+/telemetry` |

Retained messages persist the last-known position per vehicle (F1.4).

---

## Development

### Project Structure

```
├── docker-compose.yml       # Service orchestration
├── mosquitto/               # MQTT broker
│   ├── Dockerfile           # Custom image with dev credentials
│   └── config/
│       ├── mosquitto.conf   # Broker configuration
│       └── acl.conf         # Topic ACL rules
├── scripts/
│   ├── setup-passwords.ps1  # Credential generation (PowerShell)
│   └── setup-passwords.sh   # Credential generation (bash)
└── tests/
    └── integration/
        ├── test-mosquitto.ps1
        └── test-mosquitto.sh
```

### Branching

All work follows GitFlow. Feature branches branch from `develop`:

```powershell
git checkout develop
git checkout -b feature/<issue-number>-<short-desc>
```

Commits reference the issue: `Fix #N: <message>`. PRs are squash-merged into `develop`.

### Running Tests

```powershell
.\tests\integration\test-mosquitto.ps1
```

Requires the broker to be running (`docker compose up -d`).

---

## Sprints

| Sprint | Focus | Timeline |
|--------|-------|----------|
| 1 | Core Pipeline (MQTT, InfluxDB, Bridge) | Weeks 1–3 |
| 2 | Live Dashboard (WebSocket, React) | Weeks 4–6 |
| 3 | Alerts & Geofencing | Weeks 7–9 |
| 4 | History & Reports | Weeks 10–12 |
| 5 | Production Hardening | Weeks 13–14 |

---

## License

Open source. Built for self-hosting.
