@echo off
title ms-tables
cd /d "%~dp0..\ms-tables"
set MS_TABLES_DB_PORT=5433
set MS_TABLES_DB_HOST=localhost
set RABBITMQ_URL=amqp://mesaya:mesaya_secret@localhost:5672
echo Starting ms-tables...
npm run start:dev
