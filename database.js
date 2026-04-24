
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false
  }
});

pool.connect()
  .then(() => console.log("PostgreSQL veritabanına bağlandı (RENDER BULUT AKTİF!)"))
  .catch(err => console.error("Bağlantı hatası:", err));

module.exports = pool;




