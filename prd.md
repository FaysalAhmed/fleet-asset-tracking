# Project Requirement Document — Fleet & Asset Tracking System

> **Stack:** WebSockets · MQTT · InfluxDB  
> **Status:** Draft v1.0  
> **Date:** May 2026

---

## 1. Executive Summary

A real-time fleet and asset tracking platform that ingests GPS/telemetry data from vehicle-mounted IoT devices via MQTT, stores time-series data in InfluxDB, and streams live location and status updates to web clients over WebSockets. The system supports geofencing, historical trip replay, and alerting for speed, idle time, and off-route events.

---

## 2. Problem Statement

Fleet operators lack a unified view of vehicle locations, health, and driver behaviour in real time. Existing solutions are either expensive SaaS platforms or batch-processing systems that deliver stale data. An open, self-hostable pipeline is needed that:

| Pain Point | Impact |
|---|---|
| No live visibility | Dispatchers can't react to delays or route deviations |
| Batch-only analytics | Fuel theft, harsh braking, or idling identified too late |
| Vendor lock-in | Per-vehicle subscription costs scale linearly with fleet size |
| Siloed data | Cannot join GPS telemetry with maintenance logs or ERP |

---

## 3. Stakeholders

| Role | Interest |
|---|---|
| Fleet Manager | Live map, alerts, driver performance reports |
| Dispatcher | Real-time location, ETA, route adherence |
| Driver | Mobile check-in/out (future scope) |
| Maintenance Team | Engine hours, odometer, fault codes |
| Systems Admin | Deployment, uptime, data retention policies |

---

## 4. System Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   IoT Device │────▶│   MQTT       │────▶│   InfluxDB   │
│  (GPS+CAN)   │     │   Broker     │     │  (Time-series)│
└──────────────┘     │  (Mosquitto) │     └──────┬───────┘
                     └──────────────┘            │
                                                │ query
                                                ▼
                     ┌──────────────┐     ┌──────────────┐
                     │  Web Client  │◀────│  API Gateway  │
                     │  (Dashboard) │     │  (WebSocket)  │
                     └──────────────┘     └──────────────┘
```

### Data Flow

1. **Ingest** — Devices publish JSON telemetry to MQTT topics at 1–30 s intervals.
2. **Bridge** — A subscriber reads from MQTT and writes to InfluxDB (Telegraf or custom bridge).
3. **Serve** — The API Gateway exposes a WebSocket endpoint; clients subscribe to vehicle feeds.
4. **Persist** — InfluxDB retains raw data at high resolution (7 days) and downsampled aggregates (1 year).
5. **Notify** — Geofence, speed, and anomaly rules trigger alerts via the WebSocket or outbound webhook.

---

## 5. Functional Requirements

### 5.1 Data Ingestion (MQTT)

| ID | Requirement | Priority |
|---|---|---|
| F1.1 | Devices authenticate via TLS client certificates or username/password | P0 |
| F1.2 | Each device publishes to a unique topic `fleet/{vehicle_id}/telemetry` | P0 |
| F1.3 | Payload includes: `lat`, `lng`, `speed`, `heading`, `ignition`, `odometer`, `ts`, `battery_v` | P0 |
| F1.4 | Broker retains last-known position per vehicle (retained messages) | P1 |
| F1.5 | Support for `$SYS` topic monitoring (broker health) | P2 |

### 5.2 Time-Series Storage (InfluxDB)

| ID | Requirement | Priority |
|---|---|---|
| F2.1 | Raw telemetry stored in a bucket with 7-day retention | P0 |
| F2.2 | Downsampled hourly aggregates stored in a separate bucket (1-year retention) | P1 |
| F2.3 | Measurements tagged by `vehicle_id`, `fleet_id`, `device_type` | P0 |
| F2.4 | Fields indexed for range queries: `lat`, `lng`, `speed`, `odometer` | P0 |
| F2.5 | Geofence enter/exit events stored as separate measurement | P1 |

### 5.3 Real-Time Streaming (WebSockets)

| ID | Requirement | Priority |
|---|---|---|
| F3.1 | Web client opens a single WS connection and subscribes to one or more vehicle feeds | P0 |
| F3.2 | Server pushes telemetry updates at configurable frequency (min every 1 s) | P0 |
| F3.3 | Client receives alerts (geofence breach, speed threshold, ignition change) in real time | P1 |
| F3.4 | Reconnection with last-known position catch-up after disconnect | P1 |
| F3.5 | Authentication via JWT token validated on WS upgrade | P0 |

### 5.4 Fleet Dashboard

| ID | Requirement | Priority |
|---|---|---|
| F4.1 | Live map showing all vehicles with real-time position updates | P0 |
| F4.2 | Vehicle detail panel: current speed, heading, odometer, driver, status | P0 |
| F4.3 | Historical trip playback (select date range, replay at 1x–10x speed) | P1 |
| F4.4 | Geofence management: draw zones on map, assign to vehicles | P1 |
| F4.5 | Alert log with filter by vehicle, type, date range | P2 |
| F4.6 | Reports: distance travelled, idling time, max speed, fuel estimate per trip | P2 |

### 5.5 Alerting

| ID | Requirement | Priority |
|---|---|---|
| F5.1 | Configurable speed threshold per vehicle or fleet | P1 |
| F5.2 | Geofence enter/exit notifications | P1 |
| F5.3 | Ignition on/off (trip start/end) events | P1 |
| F5.4 | Device offline / heartbeat lost (configurable timeout) | P1 |
| F5.5 | Alerts delivered in-app (dashboard) and optionally via webhook/SMS | P2 |

---

## 6. Non-Functional Requirements

| ID | Requirement | Target |
|---|---|---|
| NFR1 | Max ingest latency (device → dashboard) | < 2 s at P95 |
| NFR2 | Concurrent devices supported | 10,000 per broker instance |
| NFR3 | Dashboard page load (initial) | < 3 s |
| NFR4 | Dashboard frame update rate | ≥ 1 Hz |
| NFR5 | System uptime | 99.5% (excluding planned maintenance) |
| NFR6 | Data durability | No data loss on single-broker failure; InfluxDB replication factor ≥ 2 |
| NFR7 | WebSocket message size | ≤ 10 KB per message |
| NFR8 | Browser support | Chrome, Firefox, Safari (last 2 major versions) |

---

## 7. Data Model

### 7.1 MQTT Payload (JSON)

```json
{
  "v": 1,
  "ts": "2026-05-21T10:30:00Z",
  "lat": 23.8103,
  "lng": 90.4125,
  "speed": 45.2,
  "heading": 180,
  "alt": 12,
  "ignition": true,
  "odometer": 123456.7,
  "battery_v": 12.4,
  "engine_temp": 88,
  "fuel_pct": 72
}
```

### 7.2 InfluxDB Schema

**Measurement: `telemetry`**

| Column | Type | Tag/Field |
|---|---|---|
| `vehicle_id` | string | Tag |
| `fleet_id` | string | Tag |
| `device_type` | string | Tag |
| `lat` | float | Field |
| `lng` | float | Field |
| `speed` | float | Field |
| `heading` | float | Field |
| `alt` | float | Field |
| `ignition` | bool | Field |
| `odometer` | float | Field |
| `battery_v` | float | Field |
| `engine_temp` | float | Field |
| `fuel_pct` | float | Field |

**Measurement: `geofence_events`**

| Column | Type | Tag/Field |
|---|---|---|
| `vehicle_id` | string | Tag |
| `zone_id` | string | Tag |
| `event` | string | Field (enter/exit) |
| `lat` | float | Field |
| `lng` | float | Field |

**Measurement: `trips`** (downsampled)

| Column | Type | Tag/Field |
|---|---|---|
| `vehicle_id` | string | Tag |
| `trip_id` | string | Tag |
| `start_ts` | datetime | Field |
| `end_ts` | datetime | Field |
| `distance_km` | float | Field |
| `avg_speed` | float | Field |
| `max_speed` | float | Field |
| `idle_sec` | int | Field |

### 7.3 WebSocket Message

```json
{
  "type": "telemetry_update",
  "vehicle_id": "v-001",
  "data": {
    "lat": 23.8103,
    "lng": 90.4125,
    "speed": 45.2,
    "heading": 180,
    "ts": "2026-05-21T10:30:00Z"
  }
}
```

```json
{
  "type": "alert",
  "vehicle_id": "v-001",
  "alert_type": "speed_exceeded",
  "message": "Speed 85 km/h exceeded threshold 60 km/h",
  "ts": "2026-05-21T10:30:00Z"
}
```

---

## 8. Tech Stack

| Layer | Technology | Rationale |
|---|---|---|
| **MQTT Broker** | Eclipse Mosquitto or EMQX | Lightweight, proven at scale. EMQX if clustering needed. |
| **MQTT → InfluxDB bridge** | Telegraf (MQTT input + InfluxDB output plugin) or custom Rust/Go service | Telegraf for zero-code pipeline; custom service for complex transformations. |
| **Time-series DB** | InfluxDB OSS v3 | Purpose-built for telemetry; native downsampling, Flux queries. |
| **API Gateway** | Go (Gorilla WebSocket / Fiber) or Node.js (ws / Socket.IO) | Go preferred for low-latency streaming at scale. |
| **Frontend** | React + Leaflet/MapLibre GL JS | Lightweight map rendering; WebSocket client built in. |
| **Auth** | JWT (access + refresh tokens) | Stateless; validated on WebSocket upgrade. |
| **Alert engine** | Lightweight Go goroutine or Node.js worker | Evaluate rules on each telemetry event. |
| **Deployment** | Docker Compose (single-node) / Kubernetes (production) | Consistent dev/prod environment. |

---

## 9. User Stories

### Sprint 1 — Core Pipeline

- As a **device**, I want to publish GPS data via MQTT so that my position is recorded.
- As a **systems admin**, I want telemetry to flow from MQTT to InfluxDB automatically so that data is persisted.

### Sprint 2 — Live Dashboard

- As a **fleet manager**, I want to see all my vehicles on a live map so that I know where they are.
- As a **dispatcher**, I want vehicle positions to update every second so that I can track movement in real time.

### Sprint 3 — Alerts & Geofencing

- As a **fleet manager**, I want to define geofences so that I'm notified when a vehicle enters or leaves a zone.
- As a **safety officer**, I want speed threshold alerts so that I can address reckless driving immediately.

### Sprint 4 — History & Reports

- As a **fleet manager**, I want to replay a vehicle's past trip so that I can review route adherence.
- As a **maintenance lead**, I want engine-hour and odometer reports so that I can schedule servicing.

---

## 10. Out of Scope (v1)

- Mobile driver app (check-in/out, proof of delivery)
- Integration with fuel management or ERP systems
- Video telematics / dashcam integration
- Predictive maintenance (ML models)
- Multi-tenancy / white-label dashboards

---

## 11. Milestones

| Milestone | Timeline | Deliverables |
|---|---|---|
| M1 — Pipeline MVP | Week 3 | MQTT broker running, Telegraf bridge writing to InfluxDB, simulated device publishing data |
| M2 — Live Dashboard | Week 6 | React map showing real-time vehicle positions via WebSocket |
| M3 — Alerts & Geofences | Week 9 | Geofence CRUD, alert engine, in-app notifications |
| M4 — Trip Replay & Reports | Week 12 | Historical playback, distance/idle/speed reports |
| M5 — Production Hardening | Week 14 | TLS, JWT auth, Docker Compose deploy, load test report |

---

## 12. Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| Device data loss on broker restart | High | Medium | Retained messages + InfluxDB write-ahead log |
| WebSocket connection flood from many vehicles | Medium | Low | Per-client subscription limits; paginate vehicle list |
| InfluxDB write throughput bottleneck at scale | High | Low | Batch writes; tune shard duration; use InfluxDB v3 |
| GPS drift / bad data | Medium | High | Server-side validation (speed > 300 km/h = reject); Kalman filter optional |
| MQTT broker single point of failure | High | Low | Deploy EMQX cluster with HAProxy; use mqtt over TCP with clean session false |
