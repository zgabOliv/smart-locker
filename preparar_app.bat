@echo off
REM Prepara o app Flutter: gera o Android, aplica a correcao do Gradle e as permissoes.
cd /d "%~dp0app"
call flutter create . --org br.edu.ifsp --project-name smart_locker_ifsp
copy /Y "%~dp0android_fix\build.gradle.kts" "android\build.gradle.kts"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ajustar_manifest.ps1"
call flutter pub get
echo.
echo Pronto. Agora rode a API (rodar_api.bat) e depois: flutter run
pause
