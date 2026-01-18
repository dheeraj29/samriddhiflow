@echo off
echo ----------------------------------------
echo [1/1] Building Flutter Web App...
echo ----------------------------------------

call flutter build web --release --no-web-resources-cdn

echo.
echo ✅ Build Complete!
