@echo off
rem TempestRPG console server: hosts your most recently played world for you and your friends.
rem You play on this PC too: start TempestRPG.exe, choose "Join a Friend" and enter 127.0.0.1.
rem Friends enter the public address shown below (or your LAN address on the same network).
rem Close this window (or press Ctrl+C) to stop the server; the world is saved every few seconds.
title TempestRPG server
cd /d "%~dp0"
TempestRPG.console.exe --headless -- --server %*
pause
