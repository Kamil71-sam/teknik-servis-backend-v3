@echo off
set /p mesaj="Yedekleme notunuzu girin: "
echo [%date% %time%] Bekent yedekleme baslatiliyor...

:: 1. SQL Yedek Bölümü
if not exist "..\bekent-sql-yedekler" mkdir "..\bekent-sql-yedekler"
set PGPASSWORD=123456

echo SQL yedekleniyor... lutfen bekleyin...

:: DİKKAT: Yolu ve parametreleri ayırdım, her şeyi tırnağa boğdum müdürüm!
set "PG_DUMP=\"C:\Program Files\PostgreSQL\16\bin\pg_dump.exe\""
%PG_DUMP% -U postgres -d teknik_servis_db -f "..\bekent-sql-yedekler\db_yedek_guncel.sql"

:: 2. GitHub Bölümü
echo GitHub'a gonderiliyor...
git add .
git commit -m "MANUEL YEDEK: %mesaj%"
git push origin main

echo.
echo ===========================================
echo   MUDURUM BU SEFER OLDU, SARI YAZI SUSTU!
echo ===========================================
pause  