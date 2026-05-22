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

## Repository structure

- `.git/` — VCS
- `prd.md` — Product Requirements Document
- `AGENTS.md` — This file
- `docker-compose.yml` — Root Compose file (all services)
- `mosquitto/` — MQTT broker (Dockerfile, config, ACLs)
- `scripts/` — Utility scripts (password generation, etc.)

## Development commands

### Start MQTT broker
```
docker compose up -d mosquitto
```

### Generate MQTT credentials
```
.\scripts\setup-passwords.ps1
```

### Stop all services
```
docker compose down
```

## Current setup

- MQTT broker: Eclipse Mosquitto 2 (Docker Compose, dev build)
- No Node.js / Go / Rust runtimes configured yet — `prd.md` suggests Go for the API gateway, React for the frontend.
- No linters, formatters, or test frameworks configured.
