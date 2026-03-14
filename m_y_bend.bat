@echo off
set /p mesaj="Yedekleme notunuzu girin: "
echo [%date% %time%] Bekent yedekleme baslatiliyor...

:: 1. SQL Yedekleme Bölümü
if not exist "..\bekent-sql-yedekler" mkdir "..\bekent-sql-yedekler"
set PGPASSWORD=123456

echo SQL yedekleniyor... lutfen bekleyin...

:: Yolu senin bilgisayardaki gercek yerine (C:\pgdata) gore ayarladim
"C:\pgdata\bin\pg_dump.exe" -U postgres -d teknik_servis_db -f "..\bekent-sql-yedekler\db_yedek_guncel.sql"

:: 2. GitHub Yedekleme Bölümü
echo GitHub'a gonderiliyor...
git add .
git commit -m "MANUEL YEDEK: %mesaj%"
git push origin main

echo.
echo ===========================================
echo   OPERASYON TAMAM! ARTIK GUVENDESIN MUDURUM.
echo ===========================================
pause