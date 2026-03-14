@echo off
set /p mesaj="Yedekleme notunuzu girin: "
echo [%date% %time%] Bekent yedekleme baslatiliyor...

:: 1. SQL Yedek Klasör Kontrolü
if not exist "..\bekent-sql-yedekler" mkdir "..\bekent-sql-yedekler"
set PGPASSWORD=123456

:: EN ÖNEMLİ YER: Tırnak işaretlerini ekledim ki boşluklardan dolayı "yolu bulamıyor" demesin.
set "PG_DUMP_EXE=C:\Program Files\PostgreSQL\16\bin\pg_dump.exe"
set "OUTPUT_FILE=..\bekent-sql-yedekler\db_yedek_guncel.sql"

echo SQL yedekleniyor...
"%PG_DUMP_EXE%" -U postgres -d teknik_servis_db > "%OUTPUT_FILE%"

:: 2. GitHub Yedek
echo GitHub'a gonderiliyor...
git add .
git commit -m "MANUEL YEDEK: %mesaj%"
git push origin main

echo.
echo ===========================================
echo   ISLEM TAMAM! SQL VE KODLAR GUVENDE.
echo ===========================================
pause