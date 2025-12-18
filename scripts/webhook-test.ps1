# ═══════════════════════════════════════════════════════════════════════
# WEBHOOK TEST SCRIPT - PowerShell Version (Windows)
# ═══════════════════════════════════════════════════════════════════════
# Taller 2: Pruebas de idempotencia de webhooks
# ═══════════════════════════════════════════════════════════════════════

param(
    [string]$GatewayUrl = "http://localhost:3000",
    [string]$SupabaseFunctionUrl = "https://YOUR_PROJECT.supabase.co/functions/v1",
    [string]$WebhookSecret = "your-webhook-secret-change-me"
)

# ─────────────────────────────────────────────────────────────
# Helper: Generate HMAC-SHA256 signature
# ─────────────────────────────────────────────────────────────
function Get-HmacSignature {
    param([string]$Payload, [string]$Secret)
    
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($Secret)
    $hash = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Payload))
    $signature = [BitConverter]::ToString($hash).Replace("-", "").ToLower()
    return "sha256=$signature"
}

# ─────────────────────────────────────────────────────────────
# TEST 1: Happy Path - Create reservation via Gateway
# ─────────────────────────────────────────────────────────────
function Test-HappyPath {
    Write-Host "`nTEST 1: Happy Path - Crear reserva" -ForegroundColor Yellow
    Write-Host "   Gateway: $GatewayUrl`n"
    
    $idempotencyKey = "test-reservation-$(Get-Date -UFormat %s)"
    
    Write-Host "   Creating reservation with key: $idempotencyKey"
    
    $body = @{
        userId = "user-123"
        restaurantId = "restaurant-456"
        tableId = "table-789"
        reservationDate = "2025-12-20"
        reservationTime = "2025-12-20T19:00:00Z"
        numberOfGuests = 4
        idempotencyKey = $idempotencyKey
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$GatewayUrl/reservations" `
            -Method Post `
            -ContentType "application/json" `
            -Headers @{ "X-Idempotency-Key" = $idempotencyKey } `
            -Body $body
        
        Write-Host ($response | ConvertTo-Json -Depth 5)
        Write-Host "`n   [OK] Reservation created. Check Telegram!`n" -ForegroundColor Green
    }
    catch {
        Write-Host "   ❌ Error: $_" -ForegroundColor Red
    }
}

# ─────────────────────────────────────────────────────────────
# TEST 2: Idempotency Test - Send same webhook 3 times
# ─────────────────────────────────────────────────────────────
function Test-Idempotency {
    Write-Host "`nTEST 2: Idempotency - Enviar webhook 3 veces" -ForegroundColor Yellow
    Write-Host "   Supabase Function: $SupabaseFunctionUrl/webhook-event-logger`n"
    
    $idempotencyKey = "idempotency-test-$(Get-Date -UFormat %s)"
    
    $payload = @{
        event_type = "reservation.created"
        idempotency_key = $idempotencyKey
        timestamp = (Get-Date -Format "o")
        data = @{
            reservation_id = "test-res-001"
            user_id = "user-123"
            table_id = "table-789"
            restaurant_id = "restaurant-456"
        }
    } | ConvertTo-Json -Depth 5 -Compress
    
    $signature = Get-HmacSignature -Payload $payload -Secret $WebhookSecret
    
    Write-Host "   Idempotency Key: $idempotencyKey"
    Write-Host "   Signature: $($signature.Substring(0, 30))...`n"
    
    for ($i = 1; $i -le 3; $i++) {
        Write-Host "   -> Attempt $i/3" -ForegroundColor Blue
        
        try {
            $response = Invoke-RestMethod -Uri "$SupabaseFunctionUrl/webhook-event-logger" `
                -Method Post `
                -ContentType "application/json" `
                -Headers @{
                    "X-Webhook-Signature" = $signature
                    "X-Idempotency-Key" = $idempotencyKey
                } `
                -Body $payload
            
                if ($response.duplicate -eq $true) {
                Write-Host "     WARNING: DUPLICATE detected (as expected)" -ForegroundColor Yellow
            }
            else {
                Write-Host "     [OK] Processed successfully" -ForegroundColor Green
            }
            
            Write-Host "     Response: $($response | ConvertTo-Json -Compress)`n"
        }
        catch {
            Write-Host "     ❌ Error: $_" -ForegroundColor Red
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "   ✅ Test completed. Only 1 event should be in processed_webhooks.`n" -ForegroundColor Green
}

# ─────────────────────────────────────────────────────────────
# TEST 3: Direct Telegram Notification Test
# ─────────────────────────────────────────────────────────────
function Test-TelegramDirect {
    Write-Host "`nTEST 3: Telegram Notification Direct" -ForegroundColor Yellow
    Write-Host "   Supabase Function: $SupabaseFunctionUrl/webhook-external-notifier`n"
    
    $idempotencyKey = "telegram-test-$(Get-Date -UFormat %s)"
    
    $payload = @{
        event_type = "reservation.created"
        idempotency_key = $idempotencyKey
        timestamp = (Get-Date -Format "o")
        data = @{
            reservation_id = "telegram-test-001"
            user_id = "demo-user"
            table_id = "mesa-vip-1"
            restaurant_id = "restaurante-demo"
            reservation_date = "2025-12-25"
            reservation_time = "20:00"
            number_of_guests = 6
        }
    } | ConvertTo-Json -Depth 5 -Compress
    
    $signature = Get-HmacSignature -Payload $payload -Secret $WebhookSecret
    
    Write-Host "   Sending to Telegram..."
    
    try {
        $response = Invoke-RestMethod -Uri "$SupabaseFunctionUrl/webhook-external-notifier" `
            -Method Post `
            -ContentType "application/json" `
            -Headers @{
                "X-Webhook-Signature" = $signature
                "X-Idempotency-Key" = $idempotencyKey
            } `
            -Body $payload
        
        Write-Host ($response | ConvertTo-Json -Depth 5)
        Write-Host "`n   [OK] Check your Telegram for the notification!`n" -ForegroundColor Green
    }
    catch {
        Write-Host "   ❌ Error: $_" -ForegroundColor Red
    }
}

# ─────────────────────────────────────────────────────────────
# Main Menu
# ─────────────────────────────────────────────────────────────
Write-Host "══════════════════════════════════════════════════════════════=" -ForegroundColor Blue
Write-Host "        WEBHOOK IDEMPOTENCY TEST - TALLER 2                  " -ForegroundColor Blue
Write-Host "══════════════════════════════════════════════════════════════=" -ForegroundColor Blue

Write-Host "Select test to run:"
Write-Host "  1) Happy Path (Gateway -> ms-reservations -> Webhook)"
Write-Host "  2) Idempotency Test (same webhook 3x)"
Write-Host "  3) Direct Telegram Test"
Write-Host "  4) Run all tests`n"

$choice = Read-Host "Enter choice [1-4]"

switch ($choice) {
    "1" { Test-HappyPath }
    "2" { Test-Idempotency }
    "3" { Test-TelegramDirect }
    "4" {
        Test-HappyPath
        Write-Host "─────────────────────────────────────────────────────────────"
        Test-Idempotency
        Write-Host "─────────────────────────────────────────────────────────────"
        Test-TelegramDirect
    }
    default {
        Write-Host "Invalid choice" -ForegroundColor Red
        exit 1
    }
}

Write-Host "══════════════════════════════════════════════════════════════=" -ForegroundColor Blue
Write-Host "                    TEST COMPLETED                          " -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════════════════=" -ForegroundColor Blue
