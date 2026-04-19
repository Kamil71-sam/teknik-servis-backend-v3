@echo off
color 0A
echo ===================================================
echo 🚀 KALANDAR YAZILIM - ULTRA TAM YEDEKLEME
echo ===================================================

set /p mesaj="Yedekleme notunuzu girin (Bos birakabilirsiniz): "
if "%mesaj%"=="" set mesaj="Otomatik Gunluk Yedek"

echo.
echo [1/3] SQL Veritabani Yedekleniyor...
if not exist "bekent-sql-yedekler" mkdir "bekent-sql-yedekler"
set PGPASSWORD=123456

:: Sira takibi (Senin meşhur 10'lu döngün)
if not exist "sira.txt" echo 1 > sira.txt
set /p sira=<sira.txt

"C:\pgdata\bin\pg_dump.exe" -U postgres -d teknik_servis -f "bekent-sql-yedekler\db_yedek_%sira%.sql"

:: Siradaki numara hesaplama
set /a "sira=%sira% + 1"
if %sira% gtr 10 set sira=1
echo %sira% > sira.txt

echo.
echo [2/3] Butun Kodlar GitHub Bulutuna Gonderiliyor...
git add -A
git commit -m "TAM YEDEK %sira%: %mesaj%"
git push origin main

echo.
echo [3/3] Projenin TAMAMI Masaustune Kopyalaniyor...
:: Masaustunde KALANDAR_TAM_YEDEK klasoru acip her seyi oraya klonlaruz
set HEDEF="%USERPROFILE%\Desktop\KALANDAR_TAM_YEDEK"
if not exist %HEDEF% mkdir %HEDEF%

:: robocopy ile klasoru birebir kopyaliyoruz. 
:: MÜDÜRÜN DİKKATİNE: node_modules (gereksiz kalabalık) ve .git (bulut ayarları) haric tutuldu!
robocopy . %HEDEF% /MIR /XD node_modules .git /NFL /NDL /NJH /NJS

echo.
echo ===================================================
echo ✅ ISLEM TAMAM! ZIRH GIBI OLDU!
echo 1. SQL veritabanin alindi.
echo 2. Tum kodlar GitHub'a gonderildi.
echo 3. Projenin Birebir Kopyasi (SQL dahil) Masaustune eklendi.
echo ===================================================
pause