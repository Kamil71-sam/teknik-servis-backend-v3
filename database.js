const { Pool } = require("pg");

const pool = new Pool({
  user: "postgres",
  host: "localhost",
  database: "teknik_servis",
  password: "123456",
  port: 5432,
});

pool.connect()
  .then(() => console.log("PostgreSQL veritabanına bağlandı"))
  .catch(err => console.error("Bağlantı hatası:", err));

module.exports = pool;