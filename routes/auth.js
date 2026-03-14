const express = require("express");
const router = express.Router();
const db = require("../database"); // MÜDÜR: Veritabanı anahtarını buraya ekledik

router.post("/login", async (req, res) => {
  const { email, password } = req.body;

  try {
    // MÜDÜR: Artık hayalet listeye değil, gerçek PostgreSQL tablosuna bakıyoruz
    // SELECT * dediğimiz için pgAdmin'de eklediğimiz 'role' sütunu da gelecek.
    const result = await db.query(
      "SELECT * FROM users WHERE email = $1 AND password = $2",
      [email, password]
    );

    if (result.rows.length === 0) {
      // Eğer veritabanında bu mail/şifre yoksa hata ver
      return res.status(401).json({ error: "E-posta veya şifre hatalı" });
    }

    const user = result.rows[0];

    res.json({
      success: true, // MÜDÜR: İşlem başarılı bayrağını ekledik
      message: "Giriş başarılı",
      user: {
          id: user.id,
          email: user.email,
          role: user.role || 'user' // MÜDÜR: pgAdmin'deki rolü telefona paslıyoruz
      }
    });

  } catch (err) {
    console.error("Login Hatası:", err.message);
    res.status(500).json({ error: "Sunucu hatası oluştu" });
  }
});

module.exports = router;