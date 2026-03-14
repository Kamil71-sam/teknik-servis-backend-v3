@echo off
set /p mesaj="Yedekleme notunuzu girin: "
echo [%date% %time%] Bekent yedekleme baslatiliyor...

:: 1. SQL Yedek (Klasör yoksa oluşturur)
if not exist "..\bekent-sql-yedekler" mkdir "..\bekent-sql-yedekler"
set PGPASSWORD=123456


:: SQL Yedeği - Tarih karmaşasını bitiren en sağlam kod:
"C:\Program Files\PostgreSQL\16\bin\pg_dump.exe" -U postgres -d teknik_servis_db > "..\bekent-sql-yedekler\db_yedek_otomatik.sql"



:: 2. GitHub Yedek
git add .
git commit -m "MANUEL YEDEK: %mesaj%"
git push origin main

echo.
echo Islem tamam! SQL verisi klasöre, kodlar GitHub'a kaydedildi.
pause 