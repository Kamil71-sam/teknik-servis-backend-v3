const jwt = require("jsonwebtoken");

// --- MÜDÜRÜN GÜVENLİK ŞEFİ ---
const guvenlikSefi = (req, res, next) => {
  // 1. Adamın yakasına bakıyoruz: Kart var mı? (Headers içinde Authorization arıyoruz)
  const authHeader = req.headers.authorization;

  // Kart yoksa veya "Bearer " formatında değilse kapıdan çevir
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Giriş Yasak! Yaka kartı (Token) bulunamadı." });
  }

  // 2. "Bearer [uzun_sifre]" yazısının içinden sadece şifreli kısmı alıyoruz
  const token = authHeader.split(" ")[1];

  try {
    // 3. Kart sahte mi, süresi dolmuş mu diye .env içindeki gizli anahtarımızla test ediyoruz
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // 4. Kart orijinalse, adamın kimliğini (id, email, role) sistemin içine not ediyoruz
    req.user = decoded;

    // 5. Her şey tamamsa adama "Geçebilirsin" diyoruz
    next();
  } catch (err) {
    // Kartın süresi dolmuşsa veya sahteyse yaka paça dışarı at
    return res.status(403).json({ error: "Geçersiz veya süresi dolmuş yaka kartı!" });
  }
};

module.exports = guvenlikSefi;