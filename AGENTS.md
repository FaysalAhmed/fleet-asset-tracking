# AGENTS.md — Fleet & Asset Tracking

## Project state

Greenfield. No code exists yet. The sole artifact is `prd.md` (requirements, architecture, data model). Work is driven from 14 GitHub issues spanning 5 sprints.

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

## Development commands

No build system, tests, or tooling configured yet. First task for any agent adding tooling should create the appropriate config and update this file.

## Current setup

- Node.js / Go / Rust etc. are not yet chosen — `prd.md` suggests Go for the API gateway, React for the frontend, Mosquitto/EMQX for MQTT.
- No package managers, linters, or formatters configured.
