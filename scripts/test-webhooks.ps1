# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT DE PRUEBAS - TALLER 2: IDEMPOTENT WEBHOOKS
# ═══════════════════════════════════════════════════════════════════════════════
param(
    [string]$Test = "all",
    [switch]$Help
)

# Configuracion
$GatewayUrl = "http://localhost:3000/api/v1"
$SupabaseUrl = "https://gvwmeyuuummdtimiwrny.supabase.co/functions/v1"
$WebhookSecret = "9f2b8c3d4a6e1f0b7c9d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3"
$JwtToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiI1NTBlODQwMC1lMjliLTQxZDQtYTcxNi00NDY2NTU0NDAwOTkiLCJlbWFpbCI6InRlc3RAbWVzYXlhLmNvbSIsInJvbGUiOiJ1c2VyIiwiaWF0IjoxNzY1ODYxODYxLCJleHAiOjE3NjY0NjY2NjF9.fb8E2bihfAAKeSl01fY0Wv2HXOZyZUzwru8-xRrOSk4"
$RestaurantId = "550e8400-e29b-41d4-a716-446655440000"

if ($Help) {
    Write-Host "
  USO: .\test-webhooks.ps1 [-Test <tipo>]
  
  TIPOS:
    all         - Todas las pruebas (default)
    create      - Crear reserva
    confirm     - Confirmar reserva
    cancel      - Cancelar reserva
    idempotency - Probar idempotencia
    direct      - Webhook directo a Supabase
"
    exit
}

function Write-Header($t) { Write-Host "`n================================================================" -ForegroundColor Cyan; Write-Host "  $t" -ForegroundColor Cyan; Write-Host "================================================================" -ForegroundColor Cyan }
function Write-OK($t) { Write-Host "  [OK] $t" -ForegroundColor Green }
function Write-ERR($t) { Write-Host "  [ERROR] $t" -ForegroundColor Red }
function Write-INF($t) { Write-Host "  [INFO] $t" -ForegroundColor Yellow }

function Get-RandomTableId {
    $hex = '{0:x4}' -f (Get-Random -Minimum 0 -Maximum 65535)
    return "550e8400-e29b-41d4-a716-44665544$hex"
}

function Get-HmacSig($p, $s) {
    $h = New-Object System.Security.Cryptography.HMACSHA256
    $h.Key = [System.Text.Encoding]::UTF8.GetBytes($s)
    $hash = $h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($p))
    return "sha256=" + [BitConverter]::ToString($hash).Replace("-","").ToLower()
}

# TEST: Crear Reserva
function Test-Create {
    Write-Header "TEST: CREAR RESERVA"
    $r = Get-Random
    $key = "create-$r"
    $tid = Get-RandomTableId
    $day = Get-Random -Minimum 1 -Maximum 28
    $mon = Get-Random -Minimum 1 -Maximum 12
    $dt = "2027-{0:D2}-{1:D2}" -f $mon, $day
    Write-INF "Key: $key"
    
    $body = @"
{"idempotencyKey":"$key","restaurantId":"$RestaurantId","tableId":"$tid","reservationDate":"$dt","reservationTime":"${dt}T20:00:00Z","numberOfGuests":4}
"@
    
    try {
        $res = Invoke-RestMethod -Uri "$GatewayUrl/reservations" -Method Post -Headers @{Authorization="Bearer $JwtToken";"Content-Type"="application/json"} -Body $body
        Write-OK "Reserva creada: $($res.data.id)"
        Write-INF "Mesa: $($res.data.tableId)"
        Write-INF "Estado: $($res.data.status)"
        Write-Host "  Revisa tu Telegram" -ForegroundColor Magenta
        return $res.data.id
    } catch {
        Write-ERR "Error: $($_.Exception.Message)"
        return $null
    }
}

# TEST: Confirmar Reserva
function Test-Confirm {
    param([string]$Id)
    Write-Header "TEST: CONFIRMAR RESERVA"
    if (-not $Id) { Write-INF "Creando reserva..."; $Id = Test-Create; Start-Sleep -Seconds 2 }
    if (-not $Id) { Write-ERR "No se pudo crear"; return }
    
    Write-INF "Confirmando: $Id"
    $body = '{"status":"CONFIRMED"}'
    try {
        $res = Invoke-RestMethod -Uri "$GatewayUrl/reservations/$Id/status" -Method Patch -Headers @{Authorization="Bearer $JwtToken";"Content-Type"="application/json"} -Body $body
        Write-OK "Reserva confirmada!"
        Write-Host "  Revisa tu Telegram" -ForegroundColor Magenta
    } catch { Write-ERR "Error: $($_.Exception.Message)" }
}

# TEST: Cancelar Reserva
function Test-Cancel {
    param([string]$Id)
    Write-Header "TEST: CANCELAR RESERVA"
    if (-not $Id) { Write-INF "Creando reserva..."; $Id = Test-Create; Start-Sleep -Seconds 2 }
    if (-not $Id) { Write-ERR "No se pudo crear"; return }
    
    Write-INF "Cancelando: $Id"
    $body = '{"status":"CANCELLED"}'
    try {
        $res = Invoke-RestMethod -Uri "$GatewayUrl/reservations/$Id/status" -Method Patch -Headers @{Authorization="Bearer $JwtToken";"Content-Type"="application/json"} -Body $body
        Write-OK "Reserva cancelada!"
        Write-Host "  Revisa tu Telegram" -ForegroundColor Magenta
    } catch { Write-ERR "Error: $($_.Exception.Message)" }
}

# TEST: Idempotencia
function Test-Idempotency {
    Write-Header "TEST: IDEMPOTENCIA (mismo key = 409)"
    $r = Get-Random
    $key = "idem-$r"
    $tid = Get-RandomTableId
    $dt = "2027-03-15"
    Write-INF "Key: $key"
    
    $body = @"
{"idempotencyKey":"$key","restaurantId":"$RestaurantId","tableId":"$tid","reservationDate":"$dt","reservationTime":"${dt}T19:00:00Z","numberOfGuests":2}
"@
    
    Write-INF "Primera solicitud..."
    try {
        $res = Invoke-RestMethod -Uri "$GatewayUrl/reservations" -Method Post -Headers @{Authorization="Bearer $JwtToken";"Content-Type"="application/json"} -Body $body
        Write-OK "Primera OK: $($res.data.id)"
    } catch { Write-ERR "Primera fallo"; return }
    
    Start-Sleep -Seconds 1
    Write-INF "Segunda solicitud (mismo key)..."
    try {
        Invoke-RestMethod -Uri "$GatewayUrl/reservations" -Method Post -Headers @{Authorization="Bearer $JwtToken";"Content-Type"="application/json"} -Body $body
        Write-ERR "Deberia dar 409"
    } catch {
        $st = $_.Exception.Response.StatusCode.value__
        if ($st -eq 409) { Write-OK "IDEMPOTENCIA OK! Status 409" }
        else { Write-ERR "Status $st (esperado 409)" }
    }
}

# TEST: Webhook Directo
function Test-Direct {
    Write-Header "TEST: WEBHOOK DIRECTO A SUPABASE"
    $r = Get-Random
    $ikey = "direct-$r"
    $ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $dt = "2027-06-20"
    $payload = @"
{"event_type":"reservation.created","idempotency_key":"$ikey","timestamp":"$ts","data":{"reservation_id":"direct-$r","table_id":"550e8400-e29b-41d4-a716-446655440001","restaurant_id":"$RestaurantId","reservation_date":"$dt","reservation_time":"${dt}T20:00:00Z","number_of_guests":4,"status":"PENDING"}}
"@
    
    $sig = Get-HmacSig -p $payload -s $WebhookSecret
    Write-INF "Key: $ikey"
    
    try {
        Invoke-RestMethod -Uri "$SupabaseUrl/webhook-event-logger" -Method Post -Headers @{"Content-Type"="application/json";"x-webhook-signature"=$sig;"x-idempotency-key"=$ikey} -Body $payload
        Write-OK "Enviado a event-logger"
    } catch { Write-ERR "Error logger: $($_.Exception.Message)" }
    
    try {
        Invoke-RestMethod -Uri "$SupabaseUrl/webhook-external-notifier" -Method Post -Headers @{"Content-Type"="application/json";"x-webhook-signature"=$sig;"x-idempotency-key"=$ikey} -Body $payload
        Write-OK "Enviado a notifier (Telegram)"
        Write-Host "  Revisa tu Telegram" -ForegroundColor Magenta
    } catch { Write-ERR "Error notifier: $($_.Exception.Message)" }
}

# MAIN
Write-Host "`n================================================================" -ForegroundColor White
Write-Host "  TALLER 2: IDEMPOTENT WEBHOOKS - PRUEBAS" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor White
Write-Host "  Gateway: $GatewayUrl" -ForegroundColor Gray
Write-Host "  Supabase: $SupabaseUrl" -ForegroundColor Gray

switch ($Test.ToLower()) {
    "create" { Test-Create }
    "confirm" { Test-Confirm }
    "cancel" { Test-Cancel }
    "idempotency" { Test-Idempotency }
    "direct" { Test-Direct }
    default {
        Test-Create; Start-Sleep -Seconds 2
        Test-Idempotency; Start-Sleep -Seconds 2
        Test-Confirm; Start-Sleep -Seconds 2
        Test-Cancel; Start-Sleep -Seconds 2
        Test-Direct
    }
}

Write-Host "`n================================================================" -ForegroundColor White
Write-Host "  PRUEBAS COMPLETADAS" -ForegroundColor White
Write-Host "================================================================`n" -ForegroundColor White
