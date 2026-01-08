#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# WEBHOOK TEST SCRIPT - Taller 2 Demo
# ═══════════════════════════════════════════════════════════════════════
# Este script demuestra:
# 1. Happy Path: Crear reserva → Webhook enviado → Telegram
# 2. Idempotencia: Enviar mismo webhook 3 veces → Solo 1 procesamiento
# ═══════════════════════════════════════════════════════════════════════

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration (actualizar con tus valores)
GATEWAY_URL="${GATEWAY_URL:-http://localhost:3000}"
SUPABASE_FUNCTION_URL="${SUPABASE_FUNCTION_URL:-https://YOUR_PROJECT.supabase.co/functions/v1}"
WEBHOOK_SECRET="${WEBHOOK_SECRET:-your-webhook-secret-change-me}"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}        🧪 WEBHOOK IDEMPOTENCY TEST - TALLER 2                  ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# ─────────────────────────────────────────────────────────────
# Helper: Generate HMAC signature
# ─────────────────────────────────────────────────────────────
generate_signature() {
    local payload="$1"
    local secret="$2"
    echo -n "sha256=$(echo -n "$payload" | openssl dgst -sha256 -hmac "$secret" | cut -d' ' -f2)"
}

# ─────────────────────────────────────────────────────────────
# TEST 1: Happy Path - Crear reserva via Gateway
# ─────────────────────────────────────────────────────────────
test_happy_path() {
    echo -e "${YELLOW}🔹 TEST 1: Happy Path - Crear reserva${NC}"
    echo "   Gateway: $GATEWAY_URL"
    echo ""
    
    local IDEMPOTENCY_KEY="test-reservation-$(date +%s)"
    
    echo "   Creating reservation with key: $IDEMPOTENCY_KEY"
    
    curl -s -X POST "$GATEWAY_URL/reservations" \
        -H "Content-Type: application/json" \
        -H "X-Idempotency-Key: $IDEMPOTENCY_KEY" \
        -d '{
            "userId": "user-123",
            "restaurantId": "restaurant-456",
            "tableId": "table-789",
            "reservationDate": "2025-12-20",
            "reservationTime": "2025-12-20T19:00:00Z",
            "numberOfGuests": 4
        }' | jq .
    
    echo ""
    echo -e "${GREEN}   ✅ Reservation created. Check Telegram for notification.${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# TEST 2: Idempotency Test - Send same webhook 3 times
# ─────────────────────────────────────────────────────────────
test_idempotency() {
    echo -e "${YELLOW}🔹 TEST 2: Idempotency - Enviar webhook 3 veces${NC}"
    echo "   Supabase Function: $SUPABASE_FUNCTION_URL/webhook-event-logger"
    echo ""
    
    local IDEMPOTENCY_KEY="idempotency-test-$(date +%s)"
    local PAYLOAD=$(cat <<EOF
{
    "event_type": "reservation.created",
    "idempotency_key": "$IDEMPOTENCY_KEY",
    "timestamp": "$(date -Iseconds)",
    "data": {
        "reservation_id": "test-res-001",
        "user_id": "user-123",
        "table_id": "table-789",
        "restaurant_id": "restaurant-456"
    }
}
EOF
)
    
    local SIGNATURE=$(generate_signature "$PAYLOAD" "$WEBHOOK_SECRET")
    
    echo "   Idempotency Key: $IDEMPOTENCY_KEY"
    echo "   Signature: ${SIGNATURE:0:30}..."
    echo ""
    
    for i in 1 2 3; do
        echo -e "${BLUE}   → Attempt $i/3${NC}"
        
        local RESPONSE=$(curl -s -X POST "$SUPABASE_FUNCTION_URL/webhook-event-logger" \
            -H "Content-Type: application/json" \
            -H "X-Webhook-Signature: $SIGNATURE" \
            -H "X-Idempotency-Key: $IDEMPOTENCY_KEY" \
            -d "$PAYLOAD")
        
        local IS_DUPLICATE=$(echo "$RESPONSE" | jq -r '.duplicate // false')
        
        if [ "$IS_DUPLICATE" = "true" ]; then
            echo -e "${YELLOW}     ⚠️ DUPLICATE detected (as expected)${NC}"
        else
            echo -e "${GREEN}     ✅ Processed successfully${NC}"
        fi
        
        echo "     Response: $RESPONSE"
        echo ""
        
        sleep 0.5
    done
    
    echo -e "${GREEN}   ✅ Test completed. Only 1 event should be in processed_webhooks.${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# TEST 3: Direct Telegram Notification Test
# ─────────────────────────────────────────────────────────────
test_telegram_direct() {
    echo -e "${YELLOW}🔹 TEST 3: Telegram Notification Direct${NC}"
    echo "   Supabase Function: $SUPABASE_FUNCTION_URL/webhook-external-notifier"
    echo ""
    
    local IDEMPOTENCY_KEY="telegram-test-$(date +%s)"
    local PAYLOAD=$(cat <<EOF
{
    "event_type": "reservation.created",
    "idempotency_key": "$IDEMPOTENCY_KEY",
    "timestamp": "$(date -Iseconds)",
    "data": {
        "reservation_id": "telegram-test-001",
        "user_id": "demo-user",
        "table_id": "mesa-vip-1",
        "restaurant_id": "restaurante-demo",
        "reservation_date": "2025-12-25",
        "reservation_time": "20:00",
        "number_of_guests": 6
    }
}
EOF
)
    
    local SIGNATURE=$(generate_signature "$PAYLOAD" "$WEBHOOK_SECRET")
    
    echo "   Sending to Telegram..."
    
    curl -s -X POST "$SUPABASE_FUNCTION_URL/webhook-external-notifier" \
        -H "Content-Type: application/json" \
        -H "X-Webhook-Signature: $SIGNATURE" \
        -H "X-Idempotency-Key: $IDEMPOTENCY_KEY" \
        -d "$PAYLOAD" | jq .
    
    echo ""
    echo -e "${GREEN}   ✅ Check your Telegram for the notification!${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# Main Menu
# ─────────────────────────────────────────────────────────────
echo "Select test to run:"
echo "  1) Happy Path (Gateway → ms-reservations → Webhook)"
echo "  2) Idempotency Test (same webhook 3x)"
echo "  3) Direct Telegram Test"
echo "  4) Run all tests"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
    1) test_happy_path ;;
    2) test_idempotency ;;
    3) test_telegram_direct ;;
    4) 
        test_happy_path
        echo "─────────────────────────────────────────────────────────────"
        test_idempotency
        echo "─────────────────────────────────────────────────────────────"
        test_telegram_direct
        ;;
    *) 
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    🎉 TEST COMPLETED                          ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
