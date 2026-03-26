const { Pool } = require('pg');

// MÜDÜR: Buradaki bilgileri kendi PostgreSQL ayarlarına göre doldur. 
const pool = new Pool({
  user: 'postgres', 
  host: 'localhost',
  database: 'teknik_servis', // Kendi veritabanı adını buraya yaz
  password: '123456', // Kendi şifreni buraya yaz müdürüm
  port: 5432,
});

const tablolariKur = async () => {
  try {
    console.log("🛠️ Veritabanına iniliyor, kurumsal raflar çakılıyor. Bekle usta...");

    // 1. Firmalar (Firms) Tablosu - MÜDÜR: Senin istediğin o detaylı künye burası!
    await pool.query(`
      CREATE TABLE IF NOT EXISTS firms (
          id SERIAL PRIMARY KEY,
          firma_adi VARCHAR(255) NOT NULL, -- Ünvan (Zorunlu)
          yetkili_ad_soyad VARCHAR(100),   -- Yetkili Kişi
          telefon VARCHAR(20),             -- Telefon
          faks VARCHAR(20),                -- Faks (Yeni Ekledik!)
          vergi_no VARCHAR(50),            -- Vergi Numarası
          eposta VARCHAR(100),             -- E-posta Adresi
          adres TEXT,                      -- Açık Adres
          created_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log("✅ Firmalar (firms) rafı başarıyla kuruldu!");

    // 2. Müşteriler (Customers) Tablosu (Eğer yoksa oluştur, varsa firma_id ekle)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS customers (
          id SERIAL PRIMARY KEY,
          first_name VARCHAR(100) NOT NULL,
          last_name VARCHAR(100) NOT NULL,
          phone VARCHAR(20),
          email VARCHAR(100),
          firm_id INTEGER REFERENCES firms(id) ON DELETE SET NULL, -- Firmaya bağladık müdürüm!
          created_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log("✅ Müşteriler (customers) rafı başarıyla kuruldu!");

    // 3. Cihazlar (Devices) Tablosu
    await pool.query(`
      CREATE TABLE IF NOT EXISTS devices (
          id SERIAL PRIMARY KEY,
          customer_id INTEGER REFERENCES customers(id) ON DELETE CASCADE,
          brand VARCHAR(100) NOT NULL,
          model VARCHAR(100) NOT NULL,
          serial_no VARCHAR(100),
          created_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log("✅ Cihazlar (devices) rafı başarıyla kuruldu!");

    // 4. Servis Kayıtları (Service Records) Tablosu
    await pool.query(`
      CREATE TABLE IF NOT EXISTS service_records (
          id SERIAL PRIMARY KEY,
          customer_id INTEGER REFERENCES customers(id) ON DELETE CASCADE,
          device_id INTEGER REFERENCES devices(id) ON DELETE CASCADE,
          fault_description TEXT NOT NULL,
          status VARCHAR(50) DEFAULT 'Kayıt Açıldı',
          technician_note TEXT,
          price NUMERIC(10,2) DEFAULT 0,
          created_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log("✅ Servis Kayıtları (service_records) rafı başarıyla kuruldu!");

    console.log("🚀 İŞLEM TAMAM! Tüm raflar nizamlı şekilde mühürlendi.");
  } catch (error) {
    console.error("❌ Usta dökümhanede yangın çıktı, şuna bir bak:", error);
  } finally {
    pool.end();
  }
};

tablolariKur();