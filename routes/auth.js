











const express = require("express");
const router = express.Router();
const db = require("../database"); // Veritabanı bağlantımız (PostgreSQL)
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");

// =========================================================================
// 1. YETKİLİ PERSONEL GİRİŞ KAPISI (LOGIN)
// =========================================================================
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

// =========================================================================
// 2. MÜŞTERİ CİHAZ/RANDEVU SORGULAMA KAPISI (ŞİFRESİZ)
// =========================================================================
router.post('/sorgula', async (req, res) => {
  console.log("SORGULA HIT:", req.body);
  const { servisNo, telefonSon4 } = req.body;

  if (!servisNo || !telefonSon4) {
      return res.json({ success: false, message: 'Lütfen Kayıt/Servis Numarası ve Telefon bilgilerini eksiksiz girin.' });
  }

  try {
      // -------------------------------------------------------------------------
      // A. ÖNCE ATÖLYE (SERVICES) TABLOSUNA BAKIYORUZ
      // -------------------------------------------------------------------------
      const sqlServis = `
          SELECT s.status, s.created_at, 
                 d.brand, d.model, d.cihaz_turu,
                 COALESCE(c.phone, f.telefon) as telefon
          FROM services s
          LEFT JOIN devices d ON s.device_id = d.id
          LEFT JOIN customers c ON s.customer_id = c.id
          LEFT JOIN firms f ON s.firm_id = f.id
          WHERE s.servis_no = $1
      `;

      const servisResult = await db.query(sqlServis, [servisNo]);
      const servis = servisResult.rows[0];

      if (servis) {
          const dbTelefon = servis.telefon || "";
          const temizTelefon = dbTelefon.replace(/\D/g, ''); // Harfi, boşluğu sil, sadece rakam kalsın

          // Güvenlik Kilidi: Son 4 hane tutuyor mu?
          if (temizTelefon.endsWith(telefonSon4)) {
              const cihazIsmi = [servis.brand, servis.model, servis.cihaz_turu].filter(Boolean).join(' ') || 'Bilinmeyen Cihaz';

              return res.json({
                  success: true,
                  data: {
                      tip: 'Servis',
                      cihaz: cihazIsmi,
                      durum: servis.status || 'İşlemde',
                      tarih: servis.created_at ? new Date(servis.created_at).toLocaleDateString('tr-TR') : 'Bilinmiyor'
                  }
              });
          } else {
              return res.json({ success: false, message: 'Güvenlik İhlali: Girdiğiniz telefon numarası bu kayıtla eşleşmiyor!' });
          }
      }

      // -------------------------------------------------------------------------
      // B. EĞER ATÖLYEDE YOKSA, SAHA (APPOINTMENTS) TABLOSUNA BAKIYORUZ
      // -------------------------------------------------------------------------
      const sqlRandevu = `
          SELECT r.status, r.appointment_date, r.appointment_time, r.issue_text,
                 COALESCE(c.phone, f.telefon) as telefon
          FROM appointments r
          LEFT JOIN customers c ON r.customer_id = c.id
          LEFT JOIN firms f ON r.firm_id = f.id
          WHERE r.servis_no = $1
      `;

      const randevuResult = await db.query(sqlRandevu, [servisNo]);
      const randevu = randevuResult.rows[0];

      if (randevu) {
          const dbTelefonRandevu = randevu.telefon || "";
          const temizTelefonRandevu = dbTelefonRandevu.replace(/\D/g, '');

          if (temizTelefonRandevu.endsWith(telefonSon4)) {
              // Senin o efsane pgAdmin SQL parçalama işinin Node.js versiyonu
              let cihazBilgisi = 'Saha Hizmeti / Kurulum';
              if (randevu.issue_text && randevu.issue_text.includes('CİHAZ:')) {
                  const match = randevu.issue_text.match(/CİHAZ:\s*(.*?)(?=\s*NOT:|$)/i);
                  if (match && match[1]) {
                      cihazBilgisi = match[1].trim();
                  }
              } else if (randevu.issue_text) {
                  cihazBilgisi = randevu.issue_text; 
              }

              return res.json({
                  success: true,
                  data: {
                      tip: 'Randevu',
                      cihaz: cihazBilgisi,
                      durum: randevu.status || 'Planlandı',
                      tarih: randevu.appointment_date ? new Date(randevu.appointment_date).toLocaleDateString('tr-TR') : 'Bilinmiyor',
                      saat: randevu.appointment_time || 'Saat Belirtilmedi'
                  }
              });
          } else {
              return res.json({ success: false, message: 'Güvenlik İhlali: Girdiğiniz telefon numarası bu kayıtla eşleşmiyor!' });
          }
      }

      // -------------------------------------------------------------------------
      // C. İKİ TABLODA DA YOKSA
      // -------------------------------------------------------------------------
      return res.json({ success: false, message: 'Bu numaraya ait aktif bir kayıt bulunamadı.' });

  } catch (err) {
      console.error("Sorgulama API Hatası:", err);
      return res.json({ success: false, message: 'Sunucu bağlantı hatası, lütfen daha sonra tekrar deneyin.' });
  }
});

module.exports = router;




















/*22 NİSAN
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






ESKİİ
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