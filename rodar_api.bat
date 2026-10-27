@echo off
REM Rodar a API no proprio PC (modo local). Na nuvem isto nao e necessario.
cd /d "%~dp0api"
set ASPNETCORE_URLS=http://0.0.0.0:5000
dotnet run
pause
