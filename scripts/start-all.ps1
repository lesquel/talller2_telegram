# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT DE INICIO - MESAYA MICROSERVICES
# ═══════════════════════════════════════════════════════════════════════════════
# Ejecutar: .\scripts\start-all.ps1
#
# Este script inicia todos los servicios necesarios para el Taller 2

param(
    [switch]$Stop,      # Detener todos los servicios
    [switch]$Status,    # Ver estado de los servicios
    [switch]$Rebuild,   # Reconstruir antes de iniciar
    [switch]$Help
)

$ErrorActionPreference = "Continue"

# ─────────────────────────────────────────────────────────────
# Configuración de rutas
# ─────────────────────────────────────────────────────────────
$RootPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$MsReservationsPath = Join-Path $RootPath "ms-reservations"
$MsTablesPath = Join-Path $RootPath "ms-tables"
$GatewayPath = Join-Path $RootPath "gateway"

# Variables de entorno
$env:MS_RESERVATIONS_DB_PORT = "5433"
$env:MS_RESERVATIONS_DB_HOST = "localhost"
$env:MS_TABLES_DB_PORT = "5433"
$env:MS_TABLES_DB_HOST = "localhost"
$env:REDIS_HOST = "localhost"
$env:RABBITMQ_URL = "amqp://mesaya:mesaya_secret@localhost:5672"
$env:JWT_SECRET = "ea3f74d028d6456ae2deda19571c600e7a8c7cf09166280e0fd4376a5c7cda5ef36252e16ec9fa94236c0b99198b2708c40d3c5acb1d9ef99998a5c866b018d88"

if ($Help) {
    Write-Host @"

╔═══════════════════════════════════════════════════════════════════════════════╗
║                    SCRIPT DE INICIO - MESAYA                                 ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║  Uso: .\start-all.ps1 [opciones]                                             ║
║                                                                               ║
║  Opciones:                                                                    ║
║    (sin args)   - Inicia todos los servicios                                  ║
║    -Stop        - Detiene todos los servicios                                 ║
║    -Status      - Muestra el estado de los servicios                          ║
║    -Rebuild     - Reconstruye los proyectos antes de iniciar                  ║
║    -Help        - Muestra esta ayuda                                          ║
║                                                                               ║
║  Servicios que se inician:                                                    ║
║    1. Docker (PostgreSQL, Redis, RabbitMQ)                                    ║
║    2. ms-reservations (Puerto RabbitMQ)                                       ║
║    3. ms-tables (Puerto RabbitMQ)                                             ║
║    4. Gateway (Puerto 3000)                                                   ║
║                                                                               ║
║  Después de iniciar, ejecuta:                                                 ║
║    .\scripts\test-webhooks.ps1                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝

"@
    exit
}

function Write-Banner {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                                       ║" -ForegroundColor Cyan
    Write-Host "║   ███╗   ███╗███████╗███████╗ █████╗ ██╗   ██╗ █████╗                ║" -ForegroundColor Cyan
    Write-Host "║   ████╗ ████║██╔════╝██╔════╝██╔══██╗╚██╗ ██╔╝██╔══██╗               ║" -ForegroundColor Cyan
    Write-Host "║   ██╔████╔██║█████╗  ███████╗███████║ ╚████╔╝ ███████║               ║" -ForegroundColor Cyan
    Write-Host "║   ██║╚██╔╝██║██╔══╝  ╚════██║██╔══██║  ╚██╔╝  ██╔══██║               ║" -ForegroundColor Cyan
    Write-Host "║   ██║ ╚═╝ ██║███████╗███████║██║  ██║   ██║   ██║  ██║               ║" -ForegroundColor Cyan
    Write-Host "║   ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝               ║" -ForegroundColor Cyan
    Write-Host "║                                                                       ║" -ForegroundColor Cyan
    Write-Host "║           Taller 2: Idempotent Webhooks System                        ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Status($service, $status, $detail = "") {
    $color = if ($status -eq "OK") { "Green" } elseif ($status -eq "STARTING") { "Yellow" } else { "Red" }
    $icon = if ($status -eq "OK") { "✅" } elseif ($status -eq "STARTING") { "⏳" } else { "❌" }
    Write-Host "  $icon $($service.PadRight(25)) [$status]  $detail" -ForegroundColor $color
}

function Test-Port($port) {
    $result = netstat -ano | Select-String ":$port.*LISTENING"
    return $result -ne $null
}

function Get-ServiceStatus {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║                    ESTADO DE SERVICIOS                                ║" -ForegroundColor Magenta
    Write-Host "╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
    
    # Docker
    $dockerRunning = docker ps --format "{{.Names}}" 2>$null
    if ($dockerRunning -match "mesaya-postgres") {
        Write-Status "PostgreSQL (Docker)" "OK" "Puerto 5433"
    } else {
        Write-Status "PostgreSQL (Docker)" "STOPPED"
    }
    
    if ($dockerRunning -match "mesaya-redis") {
        Write-Status "Redis (Docker)" "OK" "Puerto 6379"
    } else {
        Write-Status "Redis (Docker)" "STOPPED"
    }
    
    if ($dockerRunning -match "mesaya-rabbitmq") {
        Write-Status "RabbitMQ (Docker)" "OK" "Puerto 5672"
    } else {
        Write-Status "RabbitMQ (Docker)" "STOPPED"
    }
    
    # Node services
    if (Test-Port 3000) {
        Write-Status "Gateway" "OK" "http://localhost:3000"
    } else {
        Write-Status "Gateway" "STOPPED"
    }
    
    # Check RabbitMQ queues for microservices
    try {
        $queues = Invoke-RestMethod -Uri "http://localhost:15672/api/queues" -Credential (New-Object PSCredential("mesaya", (ConvertTo-SecureString "mesaya_secret" -AsPlainText -Force))) -ErrorAction SilentlyContinue
        
        $resQueue = $queues | Where-Object { $_.name -eq "reservations_queue" }
        $tablesQueue = $queues | Where-Object { $_.name -eq "tables_queue" }
        
        if ($resQueue -and $resQueue.consumers -gt 0) {
            Write-Status "ms-reservations" "OK" "RabbitMQ consumer"
        } else {
            Write-Status "ms-reservations" "STOPPED"
        }
        
        if ($tablesQueue -and $tablesQueue.consumers -gt 0) {
            Write-Status "ms-tables" "OK" "RabbitMQ consumer"
        } else {
            Write-Status "ms-tables" "STOPPED"
        }
    } catch {
        Write-Status "ms-reservations" "UNKNOWN" "No se pudo verificar"
        Write-Status "ms-tables" "UNKNOWN" "No se pudo verificar"
    }
    
    Write-Host ""
}

function Stop-AllServices {
    Write-Host ""
    Write-Host "🛑 Deteniendo todos los servicios..." -ForegroundColor Yellow
    Write-Host ""
    
    # Detener procesos Node
    Get-Process -Name "node" -ErrorAction SilentlyContinue | ForEach-Object {
        $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine
        if ($cmd -match "ms-reservations|ms-tables|gateway") {
            Write-Host "  Deteniendo: $($_.Id)" -ForegroundColor Yellow
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Detener Docker
    Write-Host "  Deteniendo contenedores Docker..." -ForegroundColor Yellow
    docker-compose -f "$RootPath\docker-compose.yml" down 2>$null
    
    Write-Host ""
    Write-Host "✅ Todos los servicios detenidos" -ForegroundColor Green
}

function Start-DockerServices {
    Write-Host "📦 Iniciando servicios Docker..." -ForegroundColor Cyan
    
    Push-Location $RootPath
    docker-compose up -d 2>$null
    Pop-Location
    
    # Esperar a que los servicios estén listos
    Write-Host "  Esperando a que PostgreSQL esté listo..."
    $maxAttempts = 30
    $attempt = 0
    do {
        Start-Sleep -Seconds 1
        $attempt++
        $ready = docker exec mesaya-postgres pg_isready -U mesaya 2>$null
    } while ($LASTEXITCODE -ne 0 -and $attempt -lt $maxAttempts)
    
    if ($attempt -ge $maxAttempts) {
        Write-Host "  ⚠️ PostgreSQL tardó demasiado en iniciar" -ForegroundColor Yellow
    } else {
        Write-Host "  ✅ PostgreSQL listo" -ForegroundColor Green
    }
    
    Write-Host "  ✅ Redis listo" -ForegroundColor Green
    Write-Host "  ✅ RabbitMQ listo" -ForegroundColor Green
}

function Build-Services {
    Write-Host "🔨 Compilando servicios..." -ForegroundColor Cyan
    
    Write-Host "  Compilando ms-reservations..."
    Push-Location $MsReservationsPath
    npm run build 2>$null
    Pop-Location
    
    Write-Host "  Compilando ms-tables..."
    Push-Location $MsTablesPath
    npm run build 2>$null
    Pop-Location
    
    Write-Host "  Compilando gateway..."
    Push-Location $GatewayPath
    npm run build 2>$null
    Pop-Location
    
    Write-Host "  ✅ Compilación completada" -ForegroundColor Green
}

function Start-Microservices {
    Write-Host "🚀 Iniciando microservicios..." -ForegroundColor Cyan
    
    # Purgar colas de RabbitMQ para evitar mensajes huerfanos
    Write-Host "  Limpiando colas de RabbitMQ..."
    docker exec mesaya-rabbitmq rabbitmqctl purge_queue reservations_queue 2>$null
    docker exec mesaya-rabbitmq rabbitmqctl purge_queue tables_queue 2>$null
    Write-Host "  ✅ Colas limpiadas" -ForegroundColor Green
    
    # ms-reservations
    Write-Host "  Iniciando ms-reservations..."
    Start-Process powershell -ArgumentList "-NoExit", "-Command", @"
        `$Host.UI.RawUI.WindowTitle = 'ms-reservations'
        cd '$MsReservationsPath'
        `$env:MS_RESERVATIONS_DB_PORT = '5433'
        `$env:MS_RESERVATIONS_DB_HOST = 'localhost'
        `$env:REDIS_HOST = 'localhost'
        `$env:RABBITMQ_URL = 'amqp://mesaya:mesaya_secret@localhost:5672'
        npm run start:dev
"@
    
    Start-Sleep -Seconds 3
    
    # ms-tables
    Write-Host "  Iniciando ms-tables..."
    Start-Process powershell -ArgumentList "-NoExit", "-Command", @"
        `$Host.UI.RawUI.WindowTitle = 'ms-tables'
        cd '$MsTablesPath'
        `$env:MS_TABLES_DB_PORT = '5433'
        `$env:MS_TABLES_DB_HOST = 'localhost'
        `$env:RABBITMQ_URL = 'amqp://mesaya:mesaya_secret@localhost:5672'
        npm run start:dev
"@
    
    Start-Sleep -Seconds 3
    
    # Gateway
    Write-Host "  Iniciando gateway..."
    Start-Process powershell -ArgumentList "-NoExit", "-Command", @"
        `$Host.UI.RawUI.WindowTitle = 'gateway'
        cd '$GatewayPath'
        `$env:JWT_SECRET = 'ea3f74d028d6456ae2deda19571c600e7a8c7cf09166280e0fd4376a5c7cda5ef36252e16ec9fa94236c0b99198b2708c40d3c5acb1d9ef99998a5c866b018d88'
        `$env:RABBITMQ_URL = 'amqp://mesaya:mesaya_secret@localhost:5672'
        npm run start:dev
"@
    
    Write-Host "  ✅ Microservicios iniciándose..." -ForegroundColor Green
}

# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────

Write-Banner

if ($Status) {
    Get-ServiceStatus
    exit
}

if ($Stop) {
    Stop-AllServices
    exit
}

# Iniciar servicios
Write-Host "🚀 INICIANDO SISTEMA MESAYA" -ForegroundColor Green
Write-Host ""

# 1. Docker
Start-DockerServices
Write-Host ""

# 2. Build (opcional)
if ($Rebuild) {
    Build-Services
    Write-Host ""
}

# 3. Microservicios
Start-Microservices
Write-Host ""

# Esperar a que todo esté listo
Write-Host "⏳ Esperando a que los servicios se inicien (15 segundos)..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Mostrar estado
Get-ServiceStatus

Write-Host "╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    SISTEMA INICIADO                                   ║" -ForegroundColor Green
Write-Host "╠═══════════════════════════════════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "║                                                                       ║" -ForegroundColor Green
Write-Host "║  Para probar el sistema:                                              ║" -ForegroundColor Green
Write-Host "║    .\scripts\test-webhooks.ps1                                        ║" -ForegroundColor Green
Write-Host "║                                                                       ║" -ForegroundColor Green
Write-Host "║  Endpoints:                                                           ║" -ForegroundColor Green
Write-Host "║    Gateway:     http://localhost:3000/api/v1                          ║" -ForegroundColor Green
Write-Host "║    Swagger:     http://localhost:3000/docs                            ║" -ForegroundColor Green
Write-Host "║    RabbitMQ:    http://localhost:15672 (mesaya/mesaya_secret)         ║" -ForegroundColor Green
Write-Host "║                                                                       ║" -ForegroundColor Green
Write-Host "║  Para detener: .\scripts\start-all.ps1 -Stop                          ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
