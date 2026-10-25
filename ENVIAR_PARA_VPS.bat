@echo off
chcp 65001 >nul
title Naruto 5 Online - enviar para a VPS
echo.
echo  ===== NARUTO 5 ONLINE - ENVIAR PARA A VPS =====
echo.
set /p IP="IP da VPS: "
set /p USR="Usuario SSH da VPS [root]: "
if "%USR%"=="" set USR=root

set ISO=C:\Users\i5\Desktop\ANIGA AREA DE TRABALHO\NEW NARUTO 2\NARUTO 5 DUB\GAME\NARUTO 5 DUB.iso
set BIOS=C:\Users\i5\Desktop\BIOS 2026 PS2\PS2 Bios 30004R V6 Pal.bin

if not exist "%ISO%" ( echo ISO nao encontrada: %ISO% & pause & exit /b 1 )
if not exist "%BIOS%" ( echo BIOS nao encontrada: %BIOS% & pause & exit /b 1 )

echo.
echo [1/4] Baixando o kit do GitHub na VPS (vai pedir a senha da VPS)...
ssh %USR%@%IP% "command -v git >/dev/null || (apt-get update && apt-get install -y git); if [ -d /opt/naruto5/.git ]; then git -C /opt/naruto5 pull; else git clone https://github.com/teodosioreal/NARUTINHO.git /opt/naruto5; fi; mkdir -p /opt/naruto5/jogo /opt/naruto5/bios"
if errorlevel 1 ( echo Falhou. Confira o IP e a senha. & pause & exit /b 1 )

echo.
echo [2/4] Enviando a BIOS...
scp "%BIOS%" %USR%@%IP%:/opt/naruto5/bios/
if errorlevel 1 ( pause & exit /b 1 )

echo.
if exist "%~dp0save\Mcd001.ps2" (
  echo Enviando o memory card com o save...
  ssh %USR%@%IP% "mkdir -p /opt/naruto5/save"
  scp "%~dp0save\Mcd001.ps2" %USR%@%IP%:/opt/naruto5/save/
)

echo.
echo [3/4] Enviando a ISO (2 GB, pode demorar bastante)...
scp "%ISO%" %USR%@%IP%:/opt/naruto5/jogo/naruto5.iso
if errorlevel 1 ( pause & exit /b 1 )

echo.
echo [4/4] Instalando...
ssh -t %USR%@%IP% "sudo bash /opt/naruto5/instalar.sh"
echo.
pause
