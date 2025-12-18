# 🚀 Guía de Setup Completa - Taller 2: Webhooks Idempotentes

> **Tiempo estimado:** 30-45 minutos  
> **Prerrequisitos:** Docker Desktop instalado, cuenta de Telegram, navegador web

---

## 📋 Índice

1. [Paso 1: Instalar Dependencias](#paso-1-instalar-dependencias)
2. [Paso 2: Levantar Infraestructura Docker](#paso-2-levantar-infraestructura-docker)
3. [Paso 3: Crear Proyecto en Supabase](#paso-3-crear-proyecto-en-supabase)
4. [Paso 4: Crear Tablas en Supabase](#paso-4-crear-tablas-en-supabase)
5. [Paso 5: Crear Bot de Telegram](#paso-5-crear-bot-de-telegram)
6. [Paso 6: Configurar Secrets en Supabase](#paso-6-configurar-secrets-en-supabase)
7. [Paso 7: Deploy Edge Functions](#paso-7-deploy-edge-functions)
8. [Paso 8: Configurar URLs en la Base de Datos Local](#paso-8-configurar-urls-en-la-base-de-datos-local)
9. [Paso 9: Iniciar Microservicios](#paso-9-iniciar-microservicios)
10. [Paso 10: Ejecutar Pruebas](#paso-10-ejecutar-pruebas)

---

## Paso 1: Instalar Dependencias

### 1.1 Dependencias de ms-reservations

Abre una terminal en la carpeta del proyecto y ejecuta:

```powershell
cd ms-reservations
npm install
```

Esto instalará las nuevas dependencias agregadas:

- `@nestjs/bull` - Integración de Bull con NestJS
- `bull` - Cola de trabajos con Redis
- `axios` - Cliente HTTP para enviar webhooks

### 1.2 Instalar Supabase CLI (Global)

```powershell
npm install -g supabase
```

Verifica la instalación:

```powershell
supabase --version
```

---

## Paso 2: Levantar Infraestructura Docker

### 2.1 Detener contenedores existentes (si los hay)

```powershell
cd ..  # Volver a la raíz del proyecto (mesaYa)
docker-compose down -v
```

> ⚠️ **Nota:** El flag `-v` elimina los volúmenes. Esto borrará datos existentes pero asegura que las nuevas tablas de webhook se creen.

### 2.2 Levantar servicios necesarios

```powershell
docker-compose up -d postgres redis rabbitmq
```

### 2.3 Verificar que estén corriendo

```powershell
docker-compose ps
```

Deberías ver algo como:

```
NAME               STATUS    PORTS
mesaya-postgres    Up        0.0.0.0:5432->5432/tcp
mesaya-redis       Up        0.0.0.0:6379->6379/tcp
mesaya-rabbitmq    Up        0.0.0.0:5672->5672/tcp, 0.0.0.0:15672->15672/tcp
```

### 2.4 Verificar que las tablas de webhook se crearon

```powershell
docker exec -it mesaya-postgres psql -U mesaya -d db_reservas -c "\dt"
```

Deberías ver las tablas:

- `webhook_subscriptions`
- `webhook_events`
- `webhook_deliveries`
- `processed_webhooks`

---

## Paso 3: Crear Proyecto en Supabase

### 3.1 Ir a Supabase

1. Abre tu navegador y ve a: **https://supabase.com**
2. Clic en **"Start your project"** o **"Sign In"**
3. Inicia sesión con GitHub (recomendado) o email

### 3.2 Crear nuevo proyecto

1. Clic en **"New Project"**
2. Completa los campos:
   - **Name:** `mesaya-webhooks`
   - **Database Password:** Genera una contraseña segura y **guárdala**
   - **Region:** Selecciona la más cercana (ej: `South America (São Paulo)`)
3. Clic en **"Create new project"**

### 3.3 Esperar inicialización

El proyecto tarda ~2 minutos en crearse. Verás una pantalla de "Setting up project...".

### 3.4 Obtener credenciales

Una vez listo, ve a **Settings** (⚙️) → **API** y copia:

| Credencial           | Dónde encontrarla                          |
| -------------------- | ------------------------------------------ |
| **Project URL**      | `https://gvwmeyuuummdtimiwrny.supabase.co` |
| **anon public key**  | Bajo "Project API keys"                    |
| **service_role key** | Bajo "Project API keys" (clic en "Reveal") |

> 🔒 **Importante:** El `service_role key` es secreto. No lo compartas ni lo subas a Git.

---

## Paso 4: Crear Tablas en Supabase

### 4.1 Abrir SQL Editor

1. En el dashboard de Supabase, clic en **"SQL Editor"** (icono de código en la barra lateral)
2. Clic en **"New query"**

### 4.2 Ejecutar el siguiente SQL

Copia y pega este código, luego clic en **"Run"** (o Ctrl+Enter):

```sql
-- ═══════════════════════════════════════════════════════════════════════
-- TABLAS DE WEBHOOKS - Taller 2 (Supabase)
-- ═══════════════════════════════════════════════════════════════════════

-- Extensión para UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════════════════════════════
-- 1. WEBHOOK_EVENTS: Log de todos los eventos recibidos
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
-- 2. PROCESSED_WEBHOOKS: Tabla de idempotencia (Consumer side)
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
-- Verificar creación
-- ═══════════════════════════════════════════════════════════════════════
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('webhook_events', 'processed_webhooks');
```

### 4.3 Verificar

Deberías ver en el resultado:

```
table_name
------------------
webhook_events
processed_webhooks
```

---

## Paso 5: Crear Bot de Telegram

### 5.1 Abrir BotFather

1. Abre Telegram (app móvil o web: https://web.telegram.org)
2. Busca: **@BotFather**
3. Inicia chat y envía: `/start`

### 5.2 Crear nuevo bot

1. Envía: `/newbot`
2. BotFather preguntará el nombre. Escribe: `MesaYa Notificaciones` (o el que prefieras)
3. Luego pedirá el username (debe terminar en `bot`). Escribe: `mesaya_notif_bot` (debe ser único)

### 5.3 Guardar el Token

BotFather responderá algo como:

```
Done! Congratulations on your new bot. You will find it at t.me/mesaya_notif_bot.

Use this token to access the HTTP API:
7123456789:AAHxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

📌 **Guarda este token**, lo necesitarás en el Paso 6.

### 5.4 Obtener tu Chat ID

1. **Inicia conversación con tu bot:** Busca `@mesaya_notif_bot` (el username que elegiste) y envíale cualquier mensaje, por ejemplo: `Hola`

2. **Obtener el Chat ID:** Abre esta URL en tu navegador (reemplaza `TU_TOKEN`):

```
https://api.telegram.org/bot7123456789:AAHxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/getUpdates

https://api.telegram.org/bot8424760807:AAHV89jPfoAIpycFjnRSEfqqVu2Ow36ZKjc/getUpdates

8424760807

```

3. **Buscar el chat id:** En la respuesta JSON, busca:

```json
{
  "result": [
    {
      "message": {
        "chat": {
          "id": 123456789, // ← Este es tu CHAT_ID
          "first_name": "Tu Nombre",
          "type": "private"
        }
      }
    }
  ]
}
```

📌 **Guarda este número** (ej: `123456789`), lo necesitarás en el Paso 6.

---

## Paso 6: Configurar Secrets en Supabase

### 6.1 Login en Supabase CLI

```powershell
supabase login
```

Se abrirá el navegador para autenticarte. Autoriza el acceso.

### 6.2 Vincular proyecto

```powershell
cd supabase  # Entrar a la carpeta supabase del proyecto
supabase link --project-ref gvwmeyuuummdtimiwrny
```

> 💡 **¿Dónde está el Project Ref?**  
> En el dashboard de Supabase → Settings → General → "Reference ID"  
> Es algo como: `abcdefghijklmnop`

### 6.3 Configurar los secrets

Ejecuta estos comandos (reemplaza los valores si lo deseas). He generado y usado un secreto fuerte para este repositorio:

```powershell
# Secreto para validar firmas HMAC (64 hex chars) - ya generado para el proyecto
supabase secrets set WEBHOOK_SECRET=9f2b8c3d4a6e1f0b7c9d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3

# Token del bot de Telegram (del Paso 5.3) - reemplaza por tu token real
supabase secrets set TELEGRAM_BOT_TOKEN=7123456789:AAHxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Tu Chat ID de Telegram (del Paso 5.4) - reemplaza por tu chat id real
supabase secrets set TELEGRAM_CHAT_ID=123456789
```

### 6.4 Verificar secrets

```powershell
supabase secrets list
```

Deberías ver:

```
NAME               DIGEST
TELEGRAM_BOT_TOKEN  abc123...
TELEGRAM_CHAT_ID    def456...
WEBHOOK_SECRET      ghi789...
```

---

## Paso 7: Deploy Edge Functions

### 7.1 Desplegar las funciones

Desde la carpeta `supabase`:

```powershell
# Deploy del logger (guarda eventos en DB)
supabase functions deploy webhook-event-logger --no-verify-jwt

# Deploy del notifier (envía a Telegram)
supabase functions deploy webhook-external-notifier --no-verify-jwt
```

> 💡 **`--no-verify-jwt`** permite que los webhooks lleguen sin autenticación JWT (usamos HMAC en su lugar).

### 7.2 Obtener URLs de las funciones

Las URLs siguen este formato:

```
https://gvwmeyuuummdtimiwrny.supabase.co/functions/v1/webhook-event-logger
https://gvwmeyuuummdtimiwrny.supabase.co/functions/v1/webhook-external-notifier
```

Por ejemplo, con el Project Ref de este repo `gvwmeyuuummdtimiwrny`:

```
https://gvwmeyuuummdtimiwrny.supabase.co/functions/v1/webhook-event-logger
https://gvwmeyuuummdtimiwrny.supabase.co/functions/v1/webhook-external-notifier
```

📌 **Guarda estas URLs**, las necesitarás en el Paso 8.

### 7.3 Probar que están activas

```powershell
curl https://TU_PROJECT_REF.supabase.co/functions/v1/webhook-event-logger
```

Deberías recibir:

```json
{ "error": "Method not allowed" }
```

Esto es normal porque solo aceptan POST. ¡Significa que están funcionando!

---

## Paso 8: Configurar URLs en la Base de Datos Local

### 8.1 Conectar a PostgreSQL local

```powershell
docker exec -it mesaya-postgres psql -U mesaya -d db_reservas
```

### 8.2 Actualizar las suscripciones

Ejecuta este SQL (reemplaza `TU_PROJECT_REF`):

```sql
-- Actualizar URL del Event Logger
UPDATE webhook_subscriptions
SET
  target_url = 'https://gvwmeyuuummdtimiwrny.supabase.co/functions/v1/webhook-event-logger',
  secret = '9f2b8c3d4a6e1f0b7c9d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3'
WHERE name = 'Supabase Event Logger';

-- Actualizar URL del Telegram Notifier
UPDATE webhook_subscriptions
SET
  target_url = 'https://gvwmeyuuummdtimiwrny.supabase.co/functions/v1/webhook-external-notifier',
  secret = '9f2b8c3d4a6e1f0b7c9d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3'
WHERE name = 'Supabase Telegram Notifier';

-- Verificar
SELECT name, target_url, is_active FROM webhook_subscriptions;
```

### 8.3 Salir de psql

```sql
\q
```

---

## Paso 9: Iniciar Microservicios

### 9.1 Iniciar ms-reservations

Abre una nueva terminal y configura las variables de entorno para conectar a localhost:

```powershell
cd ms-reservations

# Configurar conexiones a localhost (Docker expone puertos)
$env:DB_HOST="localhost"
$env:REDIS_HOST="localhost"
$env:RABBITMQ_HOST="localhost"

npm run dev
```

Deberías ver logs como:

```
[Nest] LOG [NestFactory] Starting Nest application...
[Nest] LOG [WebhookService] ✅ Webhook module initialized
[Nest] LOG Listening on microservice (RabbitMQ)
```

### 9.2 Iniciar ms-tables (opcional)

En otra terminal:

```powershell
cd ms-tables
npm run dev
```

### 9.3 Iniciar Gateway

En otra terminal:

```powershell
cd gateway

# Configurar conexiones si usa las mismas variables
$env:DB_HOST="localhost"
$env:REDIS_HOST="localhost"
$env:RABBITMQ_HOST="localhost"

npm run dev
```

---

## Paso 10: Ejecutar Pruebas

### 10.1 Prueba rápida con PowerShell

```powershell
cd scripts
.\webhook-test.ps1 `
  -WebhookSecret "9f2b8c3d4a6e1f0b7c9d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3" `
  -SupabaseFunctionUrl "https://gvwmeyuuummdtimiwrny.supabase.co/functions/v1"
```

Selecciona opción `4` para ejecutar todas las pruebas.

### 10.2 Prueba manual del Happy Path

1. **Crear una reserva via Gateway:**

```powershell
$body = @{
    userId = "user-demo-123"
    restaurantId = "restaurant-456"
    tableId = "table-789"
    reservationDate = "2025-12-25"
    reservationTime = "2025-12-25T20:00:00Z"
    numberOfGuests = 4
    idempotencyKey = "test-$(Get-Date -UFormat %s)"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3000/reservations" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body
```

2. **Verificar en Telegram:** Deberías recibir un mensaje como:

```
🍽️ Nueva Reserva Creada

📋 Detalles:
• ID: 550e8400-e29b-41d4-a716...
• Mesa: table-789
• Restaurante: restaurant-456
• Fecha: 2025-12-25
• Hora: 20:00
• Personas: 4

⏰ Recibido: 2025-12-15T...
```

### 10.3 Prueba de Idempotencia

Ejecuta el script y selecciona opción `2`:

```powershell
.\webhook-test.ps1 -WebhookSecret "tu-secreto" -SupabaseFunctionUrl "https://xxx.supabase.co/functions/v1"
```

Verifica:

- ✅ Primera vez: `duplicate: false`
- ✅ Segunda vez: `duplicate: true`
- ✅ Tercera vez: `duplicate: true`
- ✅ Solo 1 mensaje en Telegram

### 10.4 Verificar en Supabase

1. Ve al dashboard de Supabase → **Table Editor**
2. Revisa la tabla `webhook_events`: deberías ver los eventos
3. Revisa `processed_webhooks`: solo debe haber 1 registro por cada `idempotency_key`

---

## 🎉 ¡Listo!

Si llegaste hasta aquí, tienes funcionando:

- ✅ Microservicio que publica webhooks firmados con HMAC
- ✅ Cola de reintentos con Bull (exponential backoff)
- ✅ Edge Functions en Supabase que validan y procesan
- ✅ Idempotencia en el consumer (PostgreSQL)
- ✅ Notificaciones en Telegram

---

## 🐛 Solución de Problemas

| Problema                                   | Solución                                                                                                          |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| **"Invalid signature"**                    | El `WEBHOOK_SECRET` debe ser idéntico en `ms-reservations` (DB local) y en Supabase secrets                       |
| **No llega mensaje a Telegram**            | Verifica `TELEGRAM_BOT_TOKEN` y `TELEGRAM_CHAT_ID`. Asegúrate de haber iniciado chat con el bot                   |
| **Error de conexión a Redis**              | Verifica que Docker esté corriendo: `docker-compose ps`                                                           |
| **"getaddrinfo ENOTFOUND postgres/redis"** | Configura variables de entorno: `$env:DB_HOST="localhost"` y `$env:REDIS_HOST="localhost"` antes de `npm run dev` |
| **"Function not found"**                   | Verifica el deploy: `supabase functions list`                                                                     |
| **Edge Function error 500**                | Revisa logs: `supabase functions logs webhook-event-logger`                                                       |

---

## 📚 Referencias

- [Documentación Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Supabase CLI Reference](https://supabase.com/docs/reference/cli)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [NestJS Bull Queues](https://docs.nestjs.com/techniques/queues)
