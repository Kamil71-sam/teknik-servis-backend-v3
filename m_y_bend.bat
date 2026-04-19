@echo off
color 0A
echo ===================================================
echo 🚀 KALANDAR YAZILIM - TAM OTOMATIK YEDEKLEME
echo ===================================================

set /p mesaj="Yedekleme notunuzu girin (Bos birakabilirsiniz): "
if "%mesaj%"=="" set mesaj="Otomatik Gunluk Yedek"

echo.
echo [1/3] SQL Veritabani Yedekleniyor...
if not exist "bekent-sql-yedekler" mkdir "bekent-sql-yedekler"
set PGPASSWORD=123456

:: Sira takibi
if not exist "sira.txt" echo 1 > sira.txt
set /p sira=<sira.txt

"C:\pgdata\bin\pg_dump.exe" -U postgres -d teknik_servis -f "bekent-sql-yedekler\db_yedek_%sira%.sql"

:: Siradaki numara hesaplama (10'da bir doner)
set /a "sira=%sira% + 1"
if %sira% gtr 10 set sira=1
echo %sira% > sira.txt

echo.
echo [2/3] Butun Kodlar Paketleniyor (Git Add)...
:: Git'in her seyi (yeni, silinmis, degismis) yakalamasini garantilemek icin:
git add -A

echo.
echo [3/3] GitHub Bulutuna Gonderiliyor...
git commit -m "TAM YEDEK %sira%: %mesaj%"
git push origin main

echo.
echo ===================================================
echo ✅ ISLEM TAMAM! HEM SQL HEM DE KODLAR GITHUB'DA!
echo ===================================================
pause