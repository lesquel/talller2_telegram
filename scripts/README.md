# 📋 Scripts de Taller 2 - Idempotent Webhooks

## 🚀 Inicio Rápido

### 1. Iniciar todo el sistema

```powershell
.\scripts\start-all.ps1
```

### 2. Ejecutar pruebas

```powershell
# Prueba rápida (crear reserva + verificar idempotencia)
.\scripts\quick-test.ps1

# Todas las pruebas
.\scripts\test-webhooks.ps1

# Pruebas específicas
.\scripts\test-webhooks.ps1 -Test create      # Solo crear
.\scripts\test-webhooks.ps1 -Test confirm     # Solo confirmar
.\scripts\test-webhooks.ps1 -Test cancel      # Solo cancelar
.\scripts\test-webhooks.ps1 -Test idempotency # Solo idempotencia
.\scripts\test-webhooks.ps1 -Test direct      # Webhook directo a Supabase
```

### 3. Ver estado

```powershell
.\scripts\start-all.ps1 -Status
```

### 4. Detener todo

```powershell
.\scripts\start-all.ps1 -Stop
```

---

## 📱 Verificar en Telegram

Después de cada prueba, revisa tu bot: **@mesaya_notif_bot**

Deberías recibir notificaciones con:

- 🍽️ Nueva Reserva Creada
- ✅ Reserva Confirmada
- ❌ Reserva Cancelada

---

## 🔧 URLs Importantes

| Servicio | URL                                      |
| -------- | ---------------------------------------- |
| Gateway  | http://localhost:3000/api/v1             |
| Swagger  | http://localhost:3000/docs               |
| RabbitMQ | http://localhost:15672                   |
| Supabase | https://gvwmeyuuummdtimiwrny.supabase.co |

---

## 📊 Verificar Base de Datos

```powershell
# Ver reservaciones
docker exec -i mesaya-postgres psql -U mesaya -d db_reservas -c "SELECT id, status FROM reservations"

# Ver webhooks enviados
docker exec -i mesaya-postgres psql -U mesaya -d db_reservas -c "SELECT ws.name, wd.status FROM webhook_deliveries wd JOIN webhook_subscriptions ws ON wd.subscription_id = ws.id ORDER BY wd.id DESC LIMIT 10"

# Estadísticas
docker exec -i mesaya-postgres psql -U mesaya -d db_reservas -c "SELECT ws.name, COUNT(*) total, SUM(CASE WHEN wd.status='success' THEN 1 ELSE 0 END) ok FROM webhook_deliveries wd JOIN webhook_subscriptions ws ON wd.subscription_id = ws.id GROUP BY ws.name"
```

---

## 🔑 Credenciales de Prueba

```
JWT Token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiI1NTBlODQwMC1lMjliLTQxZDQtYTcxNi00NDY2NTU0NDAwOTkiLCJlbWFpbCI6InRlc3RAbWVzYXlhLmNvbSIsInJvbGUiOiJ1c2VyIiwiaWF0IjoxNzY1ODU4NDMxLCJleHAiOjE3NjU5NDQ4MzF9.Gl7rzx0KxON5AFD91djeuAXox_C-PKIiX9vBiYZ8icY

Webhook Secret: 9f2b8c3d4a6e1f0b7c9d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3

PostgreSQL: localhost:5433, mesaya/mesaya_secret
RabbitMQ: localhost:5672, mesaya/mesaya_secret
Redis: localhost:6379
```
