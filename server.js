const express = require("express");
const cors = require("cors"); // MÜDÜR: Bu önemli, dışardan erişimi açar
const db = require("./database");
const firmRoute = require('./routes/firm');

const app = express();

// --- 1. MIDDLEWARE AYARLARI ---
app.use(cors()); // Tüm cihazlardan (Telefon/Tablet) gelen isteklere izin ver
app.use(express.json()); // Gelen verileri JSON olarak oku
app.use('/api/firm', firmRoute);

// --- 2. ROUTE (BORU) BAĞLANTILARI ---
const customersRoutes = require("./routes/customers.js");
const devicesRoutes = require("./routes/devices");
const servicesRoutes = require("./routes/services");
const serviceNotesRoutes = require("./routes/serviceNotes");
const authRoutes = require("./routes/auth");
const uzmanRoutes = require('./routes/uzman'); // MÜDÜR: Uzman modülü eklendi

// --- 3. ANA ŞALTERLER ---
app.use("/customers", customersRoutes);
app.use("/devices", devicesRoutes);
app.use("/services", servicesRoutes);
app.use("/service-notes", serviceNotesRoutes);
app.use("/auth", authRoutes);
app.use("/uzman", uzmanRoutes); // MÜDÜR: Uzman yolu açıldı

// --- 4. TEST ROTASI ---
app.get("/", (req, res) => {
  res.send("Teknik Servis API Jilet Gibi Çalışıyor");
});

// --- 5. MOTORU ÇALIŞTIR ---
const PORT = 3000;

// MÜDÜR: '0.0.0.0' ekleyerek sunucuyu sadece kendine değil, 
// yerel ağdaki telefona da açıyoruz!
app.listen(PORT, '0.0.0.0', () => {
  console.log("-----------------------------------------");
  console.log("🚀 Server ağ üzerinden erişime açıldı!");
  console.log(`📡 Yerel Adres: http://localhost:${PORT}`);
  console.log(`📱 Telefon İçin: http://192.168.1.45:${PORT}`);
  console.log("🛠️  PostgreSQL Bağlantısı Hazır");
  console.log("-----------------------------------------");
});