#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# Script para crear las dos bases de datos (db_mesas y db_reservas)
# Se ejecuta automáticamente al iniciar el contenedor de Postgres
# ═══════════════════════════════════════════════════════════════════════

set -e

echo "🗄️  Creando bases de datos para MesaYa Microservices..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Base de datos para el microservicio de mesas (Entidad Maestra)
    CREATE DATABASE db_mesas;
    GRANT ALL PRIVILEGES ON DATABASE db_mesas TO $POSTGRES_USER;

    -- Base de datos para el microservicio de reservas (Entidad Transaccional)
    CREATE DATABASE db_reservas;
    GRANT ALL PRIVILEGES ON DATABASE db_reservas TO $POSTGRES_USER;
EOSQL

if ! psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -tAc "SELECT 1 FROM pg_database WHERE datname='mesaya'" | grep -q 1; then
    echo "🗄️  Creando base de datos monolito mesaya..."
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE DATABASE mesaya;
        GRANT ALL PRIVILEGES ON DATABASE mesaya TO $POSTGRES_USER;
EOSQL
    echo "✅ Base de datos mesaya creada"
else
    echo "⏭️  Base de datos mesaya ya existe"
fi

echo "✅ Bases de datos db_mesas y db_reservas creadas exitosamente!"

# ═══════════════════════════════════════════════════════════════════════
# TABLAS DE WEBHOOKS (Taller 2 - Idempotent Consumer)
# ═══════════════════════════════════════════════════════════════════════
echo "🔗 Creando tablas de webhooks en db_reservas..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "db_reservas" <<-EOSQL
    -- ═══════════════════════════════════════════════════════════════════════
    -- Extensión para UUIDs
    -- ═══════════════════════════════════════════════════════════════════════
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

    -- ═══════════════════════════════════════════════════════════════════════
    -- 1. WEBHOOK_SUBSCRIPTIONS: Define quién recibe webhooks
    -- ═══════════════════════════════════════════════════════════════════════
    CREATE TABLE IF NOT EXISTS webhook_subscriptions (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        name VARCHAR(100) NOT NULL,
        target_url VARCHAR(500) NOT NULL,
        secret VARCHAR(256) NOT NULL,
        event_types TEXT[] NOT NULL DEFAULT '{}',
        is_active BOOLEAN NOT NULL DEFAULT true,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );

    -- ═══════════════════════════════════════════════════════════════════════
    -- 2. WEBHOOK_EVENTS: Log de todos los eventos emitidos
    -- ═══════════════════════════════════════════════════════════════════════
    CREATE TABLE IF NOT EXISTS webhook_events (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        event_type VARCHAR(100) NOT NULL,
        payload JSONB NOT NULL,
        idempotency_key VARCHAR(256) NOT NULL UNIQUE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_webhook_events_idempotency 
        ON webhook_events(idempotency_key);
    CREATE INDEX IF NOT EXISTS idx_webhook_events_type 
        ON webhook_events(event_type);

    -- ═══════════════════════════════════════════════════════════════════════
    -- 3. WEBHOOK_DELIVERIES: Registro de intentos de entrega
    -- ═══════════════════════════════════════════════════════════════════════
    CREATE TABLE IF NOT EXISTS webhook_deliveries (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        event_id UUID NOT NULL REFERENCES webhook_events(id) ON DELETE CASCADE,
        subscription_id UUID NOT NULL REFERENCES webhook_subscriptions(id) ON DELETE CASCADE,
        status VARCHAR(20) NOT NULL DEFAULT 'pending',
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_at TIMESTAMP WITH TIME ZONE,
        next_retry_at TIMESTAMP WITH TIME ZONE,
        response_status INTEGER,
        response_body TEXT,
        error_message TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_status 
        ON webhook_deliveries(status);
    CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_next_retry 
        ON webhook_deliveries(next_retry_at) WHERE status = 'pending';

    -- ═══════════════════════════════════════════════════════════════════════
    -- 4. PROCESSED_WEBHOOKS: Tabla de idempotencia (Consumer side)
    -- ═══════════════════════════════════════════════════════════════════════
    CREATE TABLE IF NOT EXISTS processed_webhooks (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        idempotency_key VARCHAR(256) NOT NULL UNIQUE,
        event_type VARCHAR(100) NOT NULL,
        processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        response_data JSONB
    );

    CREATE INDEX IF NOT EXISTS idx_processed_webhooks_key 
        ON processed_webhooks(idempotency_key);

    -- ═══════════════════════════════════════════════════════════════════════
    -- Datos semilla: Suscripción de ejemplo (actualizar URL después del deploy)
    -- ═══════════════════════════════════════════════════════════════════════
    INSERT INTO webhook_subscriptions (name, target_url, secret, event_types, is_active)
    VALUES (
        'Supabase Event Logger',
        'https://YOUR_PROJECT.supabase.co/functions/v1/webhook-event-logger',
        '9f2b8c3d4a6e1f0b7c9d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3',
        ARRAY['reservation.created', 'reservation.confirmed', 'reservation.cancelled', 'table.occupied', 'table.released'],
        true
    ) ON CONFLICT DO NOTHING;

    INSERT INTO webhook_subscriptions (name, target_url, secret, event_types, is_active)
    VALUES (
        'Supabase Telegram Notifier',
        'https://YOUR_PROJECT.supabase.co/functions/v1/webhook-external-notifier',
        '9f2b8c3d4a6e1f0b7c9d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3',
        ARRAY['reservation.created', 'reservation.confirmed'],
        true
    ) ON CONFLICT DO NOTHING;

EOSQL

echo "✅ Tablas de webhooks creadas exitosamente!"
