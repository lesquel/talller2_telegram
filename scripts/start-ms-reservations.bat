@echo off
title ms-reservations
cd /d "%~dp0..\ms-reservations"
set MS_RESERVATIONS_DB_PORT=5433
set MS_RESERVATIONS_DB_HOST=localhost
set REDIS_HOST=localhost
set RABBITMQ_URL=amqp://mesaya:mesaya_secret@localhost:5672
echo Starting ms-reservations...
npm run start:dev
