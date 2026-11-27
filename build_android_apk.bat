@echo off
title TeleVault — Build Personal Android APK
echo ===============================================================
echo   TeleVault - Personal Android APK Builder
echo ===============================================================
echo.

where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [!] Flutter SDK is not installed on this PC yet.
    echo.
    echo You have TWO easy ways to install TeleVault on your phone right now:
    echo.
    echo   OPTION 1 (Instant Wi-Fi Mobile App Install - 0 MB download):
    echo     1. Connect your phone to the same Wi-Fi as this PC.
    echo     2. Open Chrome / Safari on your phone and visit:
    echo        http://192.168.1.103:8765
    echo     3. Tap the Browser Menu (3 dots) -^> "Add to Home Screen" / "Install App".
    echo     4. TeleVault will install on your phone home screen as a full-screen app!
    echo.
    echo   OPTION 2 (Build Standalone .APK without installing Flutter locally):
    echo     Push this folder to a private GitHub repository; the included
    echo     .github\workflows\build-apk.yml workflow automatically compiles
    echo     and gives you the downloadable app-release.apk!
    echo.
    pause
    goto :eof
)

echo [1/3] Generating Android Gradle wrapper...
call flutter create --project-name televault .

echo [2/3] Fetching packages...
call flutter pub get

echo [3/3] Building Release APK...
call flutter build apk --release

echo.
echo [DONE] Your personal APK is ready at:
echo        build\app\outputs\flutter-apk\app-release.apk
pause

