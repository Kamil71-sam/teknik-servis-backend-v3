@echo off
color 0A
echo ===================================================
echo 🚀 KALANDAR YAZILIM - ARSIV TIPI TAM YEDEKLEME
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
set /a "sira=%sira% + 1"
if %sira% gtr 10 set sira=1
echo %sira% > sira.txt

echo.
echo [2/3] Butun Kodlar GitHub Bulutuna Gonderiliyor...
git add -A
git commit -m "TAM YEDEK %sira%: %mesaj%"
git push origin main

echo.
echo [3/3] Proje Masaustune TARIHLI Olarak Arsivleniyor...

:: Klasor ismi icin Tarih ve Saat ayari
set "Gun=%date:~0,2%"
set "Ay=%date:~3,2%"
set "Yil=%date:~6,4%"
set "Saat=%time:~0,2%"
if "%Saat:~0,1%" == " " set "Saat=0%Saat:~1,1%"
set "Dakika=%time:~3,2%"

set "KLASOR_ADI=yedek_%Gun%.%Ay%.%Yil%_%Saat%_%Dakika%"
set "ANA_HEDEF=%USERPROFILE%\Desktop\KALANDAR_YEDEKLER"
set "HEDEF=%ANA_HEDEF%\%KLASOR_ADI%"

:: Masaustunde ana klasor yoksa olustur
if not exist "%ANA_HEDEF%" mkdir "%ANA_HEDEF%"
:: Icine bugunun tarihiyle klasor ac
mkdir "%HEDEF%"

:: Sadece kopyala (Ayna mantigi iptal edildi, yeni klasore arsivleniyor)
robocopy . "%HEDEF%" /E /XD node_modules .git /NFL /NDL /NJH /NJS

echo.
echo ===================================================
echo ✅ ISLEM TAMAM! YEDEK ARSIVLENDI!
echo Yeni Yerdek Klasorun: Masaustu \ KALANDAR_YEDEKLER \ %KLASOR_ADI%
echo ===================================================
pause