# Setup MQTT broker credentials
# Run: .\scripts\setup-passwords.ps1

param(
    [string]$MosquittoImage = "eclipse-mosquitto:2",
    [string]$ConfigDir = (Join-Path (Get-Location) "mosquitto/config")
)

$passwdFile = Join-Path $ConfigDir "passwords.txt"

Write-Host "=== MQTT Broker Credential Setup ===" -ForegroundColor Cyan
Write-Host "Mosquitto image: $MosquittoImage"
Write-Host "Config directory: $ConfigDir"
Write-Host ""

# Define users
$users = @(
    @{Username = "bridge";   Password = "bridge123"},
    @{Username = "gateway";  Password = "gateway123"},
    @{Username = "admin";    Password = "admin123"}
)

# Create password file using mosquitto_passwd inside Docker
Write-Host "Creating password file..." -ForegroundColor Yellow

# Start fresh
if (Test-Path $passwdFile) { Remove-Item $passwdFile }

foreach ($user in $users) {
    $u = $user.Username
    $p = $user.Password
    Write-Host "  Adding user: $u"
    docker run --rm -v "${ConfigDir}:/mosquitto/config" $MosquittoImage `
        mosquitto_passwd -b /mosquitto/config/passwords.txt $u $p 2>$null
    if (-not $?) {
        Write-Host "  Creating file with first user..." -ForegroundColor DarkYellow
        docker run --rm -v "${ConfigDir}:/mosquitto/config" $MosquittoImage `
            sh -c "touch /mosquitto/config/passwords.txt && mosquitto_passwd -b /mosquitto/config/passwords.txt $u $p"
    }
}

Write-Host ""
Write-Host "Password file created at: $passwdFile" -ForegroundColor Green
Write-Host "Users: $($users | ForEach-Object { $_.Username } | Join-String -Separator ', ')"
