require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false
  }
});

const tablolariKur = async () => {
  try {
    console.log("🛠️ Kalandar Yazılım: Frankfurt hattına tam kadro giriliyor...");

    // 1. Temel Tanımlar (Roller, Kategoriler, Markalar, Durumlar)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS roles (id SERIAL PRIMARY KEY, role_name VARCHAR(50) UNIQUE NOT NULL);
      CREATE TABLE IF NOT EXISTS categories (id SERIAL PRIMARY KEY, name VARCHAR(100) NOT NULL);
      CREATE TABLE IF NOT EXISTS brands (id SERIAL PRIMARY KEY, name VARCHAR(100) NOT NULL);
      CREATE TABLE IF NOT EXISTS service_status (id SERIAL PRIMARY KEY, status_name VARCHAR(50) NOT NULL);
    `);
    console.log("✅ Temel tanımlar (roller, markalar, kategoriler) kuruldu!");

    // 2. Firmalar ve Müşteriler
    await pool.query(`
      CREATE TABLE IF NOT EXISTS firms (
          id SERIAL PRIMARY KEY,
          firma_adi VARCHAR(255) NOT NULL,
          yetkili_ad_soyad VARCHAR(100),
          telefon VARCHAR(20),
          faks VARCHAR(20),
          vergi_no VARCHAR(50),
          eposta VARCHAR(100),
          adres TEXT,
          created_at TIMESTAMP DEFAULT NOW()
      );
      CREATE TABLE IF NOT EXISTS customers (
          id SERIAL PRIMARY KEY,
          first_name VARCHAR(100) NOT NULL,
          last_name VARCHAR(100) NOT NULL,
          phone VARCHAR(20),
          email VARCHAR(100),
          firm_id INTEGER REFERENCES firms(id) ON DELETE SET NULL,
          created_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log("✅ Firmalar ve Müşteriler rafları kuruldu!");

    // 3. Kullanıcılar ve Cihaz Modelleri
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
          id SERIAL PRIMARY KEY, 
          username VARCHAR(50) UNIQUE NOT NULL, 
          password TEXT NOT NULL, 
          role_id INTEGER REFERENCES roles(id),
          created_at TIMESTAMP DEFAULT NOW()
      );
      CREATE TABLE IF NOT EXISTS device_models (
          id SERIAL PRIMARY KEY,
          brand_id INTEGER REFERENCES brands(id),
          model_name VARCHAR(100) NOT NULL
      );
    `);
    console.log("✅ Kullanıcılar ve Modeller mühürlendi!");

    // 4. Cihazlar ve Servis Kayıtları
    await pool.query(`
      CREATE TABLE IF NOT EXISTS devices (
          id SERIAL PRIMARY KEY,
          customer_id INTEGER REFERENCES customers(id) ON DELETE CASCADE,
          brand VARCHAR(100) NOT NULL,
          model VARCHAR(100) NOT NULL,
          serial_no VARCHAR(100),
          created_at TIMESTAMP DEFAULT NOW()
      );
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
    console.log("✅ Cihazlar ve Servis Kayıtları aktif edildi!");

    // 5. Parçalar, Stok ve Loglar
    await pool.query(`
      CREATE TABLE IF NOT EXISTS parts (
          id SERIAL PRIMARY KEY, 
          part_name VARCHAR(255) NOT NULL, 
          category_id INTEGER REFERENCES categories(id),
          stock_quantity INTEGER DEFAULT 0,
          price NUMERIC(10,2)
      );
      CREATE TABLE IF NOT EXISTS stock_movements (
          id SERIAL PRIMARY KEY,
          part_id INTEGER REFERENCES parts(id),
          quantity INTEGER,
          type VARCHAR(20),
          created_at TIMESTAMP DEFAULT NOW()
      );
      CREATE TABLE IF NOT EXISTS logs (
          id SERIAL PRIMARY KEY,
          user_id INTEGER,
          action TEXT,
          created_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log("✅ Stok, Parçalar ve Log kayıtları tamamlandı!");

    console.log("🚀 MÜJDE MÜDÜRÜM! 14 Tablonun tamamı Almanya'ya nizamlıca çakıldı.");
  } catch (error) {
    console.error("❌ Müdürüm dökümhanede yangın çıktı:", error);
  } finally {
    pool.end();
  }
};

tablolariKur();