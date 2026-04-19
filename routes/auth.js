


const express = require("express");
const router = express.Router();
const db = require("../database");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");

router.post("/login", async (req, res) => {
  console.log("LOGIN HIT:", req.body);

  const { email, password } = req.body;

  try {
    const result = await db.query(
      "SELECT * FROM users WHERE email = $1",
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: "E-posta veya şifre hatalı" });
    }

    const user = result.rows[0];
    let isPasswordValid = false;

    if (
      typeof user.password === "string" &&
      (user.password.startsWith("$2b$") || user.password.startsWith("$2a$"))
    ) {
      isPasswordValid = await bcrypt.compare(password, user.password);
    } else {
      isPasswordValid = password === user.password;
    }

    if (!isPasswordValid) {
      return res.status(401).json({ error: "E-posta veya şifre hatalı" });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: "24h" }
    );

    return res.json({
      success: true,
      message: "Giriş başarılı",
      token,
      user: {
        id: user.id,
        email: user.email,
        role: user.role || "user",
      },
    });
  } catch (err) {
    console.error("Login Hatası:", err);
    return res.status(500).json({ error: "Sunucu hatası oluştu" });
  }
});

module.exports = router;






/*
const express = require("express");
const router = express.Router();
const db = require("../database"); // MÜDÜR: Veritabanı anahtarı
const jwt = require("jsonwebtoken"); // MÜDÜR: Dijital yaka kartı basma makinesi eklendi
const bcrypt = require("bcrypt"); // MÜDÜR: Kıyma makinesi sisteme dahil edildi

router.post("/login", async (req, res) => {
  const { email, password } = req.body;

  try {
    // MÜDÜR: Sadece e-postaya göre kapıyı çalıyoruz (Şifreyi SQL'de sormuyoruz)
    const result = await db.query(
      "SELECT * FROM users WHERE email = $1",
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: "E-posta veya şifre hatalı" });
    }

    const user = result.rows[0];
    let isPasswordValid = false;

    // --- MÜDÜR: HİBRİT GÜVENLİK KONTROLÜ BAŞLIYOR ---
    // Eğer şifre $2b$ veya $2a$ ile başlıyorsa yeni nesil bcrypt şifresidir
    if (user.password.startsWith("$2b$") || user.password.startsWith("$2a$")) {
      isPasswordValid = await bcrypt.compare(password, user.password);
    } else {
      // Değilse eski usul (123456 gibi) açık şifredir, direkt eşleştir
      isPasswordValid = (password === user.password);
    }

    // Eğer şifre iki testten de geçemezse kapı duvar
    if (!isPasswordValid) {
      return res.status(401).json({ error: "E-posta veya şifre hatalı" });
    }

    // --- MÜDÜR: GİZLİ KASADAKİ ANAHTARLA KİMLİK KARTI (TOKEN) ÜRETİYORUZ ---
    // Bu kartın içine kullanıcının temel bilgilerini mühürlüyoruz.
    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      process.env.JWT_SECRET, // .env dosyasından gelen gizli şifremiz
      { expiresIn: "24h" } // Kartın geçerlilik süresi (24 saat)
    );

    res.json({
      success: true,
      message: "Giriş başarılı",
      token: token, // MÜDÜR: Ürettiğimiz yaka kartını telefona yolluyoruz
      user: {
          id: user.id,
          email: user.email,
          role: user.role || 'user'
      }
    });

  } catch (err) {
    console.error("Login Hatası:", err.message);
    res.status(500).json({ error: "Sunucu hatası oluştu" });
  }
});

module.exports = router;*/