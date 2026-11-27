@echo off
title TeleVault — Live Telegram MTProto Bridge ^& App Launcher
echo ===============================================================
echo   TeleVault - Personal File Manager ^& Live Telegram Cloud
echo ===============================================================
echo.
echo [1/2] Starting Live Telegram MTProto Bridge Server (Telethon) on port 8765...
start "" "http://localhost:8765/preview/index.html"
python "%~dp0backend\telegram_bridge_server.py"
