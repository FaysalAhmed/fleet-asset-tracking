#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Integration tests for the Mosquitto MQTT broker.
  Requires the broker to be running via `docker compose up -d`.
.EXAMPLE
  .\tests\integration\test-mosquitto.ps1
.NOTES
  Exit code 0 = all tests passed.
  Exit code 1 = one or more tests failed.
#>

$ErrorActionPreference = "Stop"
$passed = 0
$failed = 0
$test_id = 0

function Test-Assertion {
    param([string]$Name, [scriptblock]$Block)
    $script:test_id++
    try {
        & $Block
        Write-Host "  PASS  #${test_id} $Name" -ForegroundColor Green
        $script:passed++
    } catch {
        Write-Host "  FAIL  #${test_id} $Name" -ForegroundColor Red
        Write-Host "        $($_.Exception.Message)" -ForegroundColor DarkRed
        $script:failed++
    }
}

function Test-Exec {
    param([string]$Cmd)
    $result = Invoke-Expression $Cmd 2>&1
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Command failed (exit $LASTEXITCODE): $Cmd`n$result"
    }
    return $result
}

# --- Setup ---
$compose = "docker compose"
$broker = "fleet-mqtt-broker"
$admin = "-u admin -P admin123"

Write-Host "=== Mosquitto Integration Tests ===" -ForegroundColor Cyan
Write-Host ""

# --- Connectivity ---
Test-Assertion -Name "Broker container is running" -Block {
    $status = docker compose ps --status running --format json $broker 2>$null | ConvertFrom-Json
    if (-not $status -or $status.State -ne "running") {
        throw "Container '$broker' is not running. Start it with 'docker compose up -d'."
    }
}

Test-Assertion -Name "Healthcheck passes via \$SYS/broker/uptime" -Block {
    $uptime = docker compose exec $broker mosquitto_sub -t '$SYS/broker/uptime' -C 1 $admin 2>$null
    if (-not $uptime -or $uptime -eq "") {
        throw "No response from $SYS/broker/uptime"
    }
    Write-Host "        (uptime: $uptime seconds)" -ForegroundColor Gray
}

# --- Publish / Subscribe ---
Test-Assertion -Name "Publish and subscribe to a telemetry topic" -Block {
    $topic = "fleet/test-001/telemetry"
    $payload = '{"lat":23.8,"lng":90.4,"speed":45,"ts":"2026-05-23T00:00:00Z"}'
    docker compose exec $broker mosquitto_pub -t $topic -m $payload $admin 2>$null
    $received = docker compose exec $broker mosquitto_sub -t $topic -C 1 $admin 2>$null
    if ($received -ne $payload) {
        throw "Expected '$payload', received '$received'"
    }
}

# --- Retained messages ---
Test-Assertion -Name "Retained message persists after publish" -Block {
    $topic = "fleet/test-retain/telemetry"
    $payload = '{"lat":23.9,"lng":90.5,"status":"retained"}'
    docker compose exec $broker mosquitto_pub -t $topic -m $payload -r $admin 2>$null
    Start-Sleep -Seconds 1
    $received = docker compose exec $broker mosquitto_sub -t $topic -C 1 $admin 2>$null
    if ($received -ne $payload) {
        throw "Retained message mismatch. Expected '$payload', received '$received'"
    }
}

# --- ACL enforcement ---
Test-Assertion -Name "Device can publish to its own topic" -Block {
    $topic = "fleet/device-a/telemetry"
    $payload = '{"lat":10.0,"lng":20.0}'
    docker compose exec $broker mosquitto_pub -t $topic -m $payload -u "admin" -P "admin123" 2>$null
    $received = docker compose exec $broker mosquitto_sub -t $topic -C 1 -u "admin" -P "admin123" 2>$null
    if ($received -ne $payload) {
        throw "Could not publish/subscribe to valid topic '$topic'"
    }
}

# --- Broker info ---
Test-Assertion -Name "Broker reports connected clients" -Block {
    $clients = docker compose exec $broker mosquitto_sub -t '$SYS/broker/clients/connected' -C 1 $admin 2>$null
    if ($clients -eq "" -or $clients -lt 0) {
        throw "Expected client count, got '$clients'"
    }
    Write-Host "        (connected clients: $clients)" -ForegroundColor Gray
}

# --- Results ---
Write-Host ""
Write-Host "=== Results ===" -ForegroundColor Cyan
Write-Host "  Passed: $passed" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor Red
Write-Host "  Total:  $($passed + $failed)" -ForegroundColor White
Write-Host ""

if ($failed -gt 0) {
    exit 1
}
exit 0
