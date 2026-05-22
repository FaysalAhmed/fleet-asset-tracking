# AGENTS.md — Fleet & Asset Tracking

## Project state

Work is driven from 14 GitHub issues spanning 5 sprints. The core pipeline is in progress — MQTT broker via Docker Compose, with InfluxDB bridge, API gateway, and frontend added in later sprints.

## Source of truth

`prd.md` defines the system — stack, schema, functional requirements (F1–F5), NFRs, milestones, and risks. Always read it before implementing.

## Issue workflow (GitFlow)

Each issue must follow GitFlow:

1. Create a feature branch from `develop`:  
   `git checkout develop; git checkout -b feature/<issue-number>-<short-desc>`
2. Commit with messages referencing the issue: `Fix #N: <message>`
3. Open a PR into `develop` when done.
4. Squash-merge and delete the feature branch.
5. Release branches (`release/*`) and hotfix branches (`hotfix/*`) from `main` for production releases.

## Definition of Done

Before marking an issue complete, the PR must:
- [ ] Include code changes with passing integration tests (`tests/integration/`)
- [ ] Include or reference a manual verification recipe
- [ ] Update `AGENTS.md` if new commands, services, or conventions were introduced
- [ ] Have no dangling branches — feature branch must be deleted after squash-merge

## Repository structure

- `.git/` — VCS
- `prd.md` — Product Requirements Document
- `AGENTS.md` — This file
- `docker-compose.yml` — Root Compose file (all services)
- `mosquitto/` — MQTT broker (Dockerfile, config, ACLs)
- `scripts/` — Utility scripts (password generation, etc.)
- `tests/integration/` — Integration test suites per service

## Service architecture

### MQTT Broker (Mosquitto)

- **Topics**: `fleet/{vehicle_id}/telemetry` per device (F1.2)
- **Auth**: password file baked into image at build time (3 users: `bridge`, `gateway`, `admin`)
- **ACLs**: devices can only write to their own topic; `bridge`/`gateway` read all; `admin` has full access
- **Retained messages**: enabled (F1.4) — last-known position per vehicle served on subscribe
- **Ports**: 1883 (MQTT), 9001 (WebSocket)
- **Healthcheck**: subscribes to `$SYS/broker/uptime` (F1.5)
- **TLS**: commented out in config, to be enabled in Sprint 5

## Development commands

### Prerequisites
- Docker Desktop (required — all services run in containers)
- No language runtimes needed locally; Go/Rust/Node are used inside containers

### Start MQTT broker
```powershell
# Build (required after config changes):
docker compose build mosquitto

# Start:
docker compose up -d mosquitto

# View logs:
docker compose logs -f mosquitto

# Stop:
docker compose down
```

### Generate MQTT credentials
```powershell
# Run from repo root:
.\scripts\setup-passwords.ps1
```
Note: credentials are baked into the Docker image at build time. The script is only needed if running Mosquitto directly (outside Compose).

### Verify broker is running
```powershell
# Healthcheck:
docker compose ps mosquitto

# Publish a test message:
docker compose exec mosquitto mosquitto_pub -h localhost -t "fleet/v001/telemetry" -m '{"lat":23.8,"lng":90.4}' -u admin -P admin123 -r

# Subscribe to confirm:
docker compose exec mosquitto mosquitto_sub -h localhost -t "fleet/+/telemetry" -C 1 -u admin -P admin123

# Check broker health via $SYS:
docker compose exec mosquitto mosquitto_sub -t '$SYS/broker/uptime' -C 1 -u admin -P admin123
```

### Run integration tests
```powershell
# Full integration suite (requires running broker):
.\tests\integration\test-mosquitto.ps1

# Or via bash:
bash .\tests\integration\test-mosquitto.sh
```

### Stop all services
```powershell
docker compose down -v   # -v also removes volumes
```

## Testing

All tests live in `tests/integration/` per service. Integration tests assume the service is already running (they test against live containers, not in-isolation).

- **Mosquitto tests**: connect, publish, subscribe, retain, ACL enforcement
- Future services will add their own test suites to the same directory

## Current setup

- MQTT broker: Eclipse Mosquitto 2 (Docker Compose, dev build)
- No Node.js / Go / Rust runtimes configured yet — `prd.md` suggests Go for the API gateway, React for the frontend.
- No linters, formatters, or language-specific test frameworks configured.
