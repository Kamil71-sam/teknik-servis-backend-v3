@echo off
set /p mesaj="Yedekleme notunuzu girin: "
echo [%date% %time%] Bekent yedekleme baslatiliyor...

:: 1. SQL Yedek Bölümü
if not exist "..\bekent-sql-yedekler" mkdir "..\bekent-sql-yedekler"
set PGPASSWORD=123456

echo SQL yedekleniyor... lutfen bekleyin...

:: Önce PostgreSQL klasörüne giriyoruz (En garanti yol budur müdürüm)
cd /d "C:\Program Files\PostgreSQL\16\bin"

:: Şimdi komutu "evindeymiş gibi" çalıştırıyoruz
pg_dump.exe -U postgres -d teknik_servis_db -f "%~dp0..\bekent-sql-yedekler\db_yedek_guncel.sql"

:: Tekrar dükkan klasörüne geri dönüyoruz
cd /d "%~dp0"

:: 2. GitHub Bölümü
echo GitHub'a gonderiliyor...
git add .
git commit -m "MANUEL YEDEK: %mesaj%"
git push origin main

echo.
echo ===========================================
echo   MUDURUM BU SEFER CORTLADI! SİSTEM TAMAM.
echo ===========================================
pause