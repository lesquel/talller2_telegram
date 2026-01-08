# ═══════════════════════════════════════════════════════════════════════════════
# PRUEBA RÁPIDA - Crear una reserva y ver la notificación en Telegram
# ═══════════════════════════════════════════════════════════════════════════════
# Ejecutar: .\scripts\quick-test.ps1

$token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiI1NTBlODQwMC1lMjliLTQxZDQtYTcxNi00NDY2NTU0NDAwOTkiLCJlbWFpbCI6InRlc3RAbWVzYXlhLmNvbSIsInJvbGUiOiJ1c2VyIiwiaWF0IjoxNzY1ODYxODYxLCJleHAiOjE3NjY0NjY2NjF9.fb8E2bihfAAKeSl01fY0Wv2HXOZyZUzwru8-xRrOSk4"

$random = Get-Random
$tableRandom = Get-Random -Minimum 10 -Maximum 99
$dayRandom = Get-Random -Minimum 1 -Maximum 28
$monthRandom = Get-Random -Minimum 1 -Maximum 12
$key = "quick-test-$random"
$tableId = "550e8400-e29b-41d4-a716-4466554400$tableRandom"
$resDate = "2026-{0:D2}-{1:D2}" -f $monthRandom, $dayRandom

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  PRUEBA RAPIDA - TALLER 2 WEBHOOKS" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  IdempotencyKey: $key" -ForegroundColor Yellow
Write-Host "  Mesa: $tableId" -ForegroundColor Yellow
Write-Host "  Fecha: $resDate" -ForegroundColor Yellow
Write-Host ""

# JSON literal para evitar problemas de codificación
$body = @"
{
    "idempotencyKey": "$key",
    "restaurantId": "550e8400-e29b-41d4-a716-446655440000",
    "tableId": "$tableId",
    "reservationDate": "$resDate",
    "reservationTime": "${resDate}T20:00:00Z",
    "numberOfGuests": 4
}
"@

try {
    $result = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/reservations" -Method Post -Headers @{
        Authorization = "Bearer $token"
        "Content-Type" = "application/json"
    } -Body $body

    Write-Host "  [OK] RESERVA CREADA" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Detalles:" -ForegroundColor White
    Write-Host "     ID: $($result.data.id)" -ForegroundColor Gray
    Write-Host "     Mesa: $($result.data.tableId)" -ForegroundColor Gray
    Write-Host "     Fecha: $($result.data.reservationDate)" -ForegroundColor Gray
    Write-Host "     Personas: $($result.data.numberOfGuests)" -ForegroundColor Gray
    Write-Host "     Estado: $($result.data.status)" -ForegroundColor Gray
    Write-Host "     Tiempo: $($result.meta.processingTime)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Revisa tu Telegram @mesaya_notif_bot" -ForegroundColor Magenta
    Write-Host ""
    
    # Probar idempotencia
    Write-Host "  Probando idempotencia (mismo key)..." -ForegroundColor Cyan
    try {
        Invoke-RestMethod -Uri "http://localhost:3000/api/v1/reservations" -Method Post -Headers @{
            Authorization = "Bearer $token"
            "Content-Type" = "application/json"
        } -Body $body
        Write-Host "  [ERROR] Deberia haber dado 409" -ForegroundColor Red
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        if ($status -eq 409) {
            Write-Host "  [OK] IDEMPOTENCIA OK - Status 409 recibido" -ForegroundColor Green
        } else {
            Write-Host "  [ERROR] Status $status (esperado 409)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
