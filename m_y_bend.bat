
@echo off
set /p mesaj="Yedekleme notunuzu girin (Ornegin: SQL Tablolari Bitti): "
echo [%date% %time%] Bekent yedekleme baslatiliyor...

:: 1. Bilgisayara SQL Yedeği Al (PostgreSQL Kayıtları)
:: MÜDÜR: Şifreyi buraya gömdüm, sana bir daha sormaz.
set PGPASSWORD=123456

if not exist "..\bekent-sql-yedekler" mkdir "..\bekent-sql-yedekler"
"C:\Program Files\PostgreSQL\16\bin\pg_dump.exe" -U postgres -d teknik_servis_db > "..\bekent-sql-yedekler\db_yedek_%date%.sql"

:: 2. Kodları GitHub'a gönder (Bulut Yedek)
git add .
git commit -m "MANUEL YEDEK: %mesaj%"
git push origin main

echo.
echo Islem tamam! Hem SQL Veritabanı bilgisayara, hem kodlar GitHub'a kaydedildi.
pause