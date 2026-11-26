@echo off
chcp 65001 >nul
title Video Pro Max (Flutter)
cd /d "%~dp0"

if not exist "build\windows\x64\runner\Release\video_hub_flutter.exe" (
  echo [ERROR] 还没有构建产物，请先在项目根目录执行：
  echo   flutter build windows --release
  echo.
  echo 如果提示找不到 flutter，请把 Flutter SDK 的 bin 目录加入系统 PATH。
  pause
  exit /b 1
)

start "" "build\windows\x64\runner\Release\video_hub_flutter.exe"
