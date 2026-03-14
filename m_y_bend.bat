@echo off
set /p mesaj="Yedekleme notunuzu girin: "
echo [%date% %time%] Bekent 10'lu yedekleme sistemi baslatiliyor...

:: 1. SQL Yedek Klasör Kontrolü
if not exist "..\bekent-sql-yedekler" mkdir "..\bekent-sql-yedekler"
set PGPASSWORD=123456

:: Sira takibi icin bir dosya kullanalim (yoksa olusturur)
if not exist "sira.txt" echo 1 > sira.txt
set /p sira=<sira.txt

echo SQL yedekleniyor (Yedek No: %sira%)...

:: Yedekleme islemi (C:\pgdata\bin yolunu kullaniyoruz)
"C:\pgdata\bin\pg_dump.exe" -U postgres -d teknik_servis -f "..\bekent-sql-yedekler\db_yedek_%sira%.sql"

:: Siradaki numara icin hesaplama yapalim
set /a "sira=%sira% + 1"
if %sira% gtr 10 set sira=1
echo %sira% > sira.txt

:: 2. GitHub Yedekleme
echo GitHub'a gonderiliyor...
git add .
git commit -m "MANUEL YEDEK %sira%: %mesaj%"
git push origin main

echo.
echo ===========================================
echo   YEDEK %sira% ALINDI. 10 YEDEKTE BIR DONER.
echo ===========================================
pause