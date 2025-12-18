@echo off
echo ========================================
echo   MESAYA - INICIANDO SERVICIOS
echo ========================================
echo.

cd /d "%~dp0"

REM Purgar cola de RabbitMQ
echo Purgando cola de RabbitMQ...
docker exec mesaya-rabbitmq rabbitmqctl purge_queue reservations_queue 2>nul

echo.
echo Iniciando servicios en ventanas separadas...
echo.

start "ms-reservations" cmd /k start-ms-reservations.bat
timeout /t 5 /nobreak >nul

start "ms-tables" cmd /k start-ms-tables.bat
timeout /t 3 /nobreak >nul

start "gateway" cmd /k start-gateway.bat

echo.
echo ========================================
echo   SERVICIOS INICIADOS
echo ========================================
echo.
echo Espera ~15 segundos para que todo este listo
echo Luego ejecuta: .\scripts\test-webhooks.ps1
echo.
pause
