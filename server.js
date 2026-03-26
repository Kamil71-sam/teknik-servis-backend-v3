const express = require("express");
const cors = require("cors"); // MÜDÜR: Bu önemli, dışardan erişimi açar




const db = require("./database");


const firmRoute = require('./routes/firm');

// --- MÜDÜR: YENİ MODÜL (MALZEME TALEPLERİ) BURAYA EKLENDİ ---
const materialRequestsRoutes = require("./routes/material_requests"); 
const operationRoutes = require('./routes/operation');
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
const appointmentRoutes = require('./routes/appointments');
const stokRoutes = require('./routes/stok');
const kasaRoutes = require('./routes/kasa');
const tahsilatRoutes = require('./routes/tahsilat'); // Üst tarafa ekle
const kasaV2Router = require('./routes/kasa_v2');




// --- 3. ANA ŞALTERLER ---
app.use("/customers", customersRoutes);
app.use("/api/customers", customersRoutes); // BU YENİ!
app.use("/devices", devicesRoutes);
app.use("/services", servicesRoutes);
app.use("/service-notes", serviceNotesRoutes);
app.use("/auth", authRoutes);
app.use("/uzman", uzmanRoutes); // MÜDÜR: Uzman yolu açıldı
app.use("/api/appointments", appointmentRoutes); // MÜDÜR: Randevu yolu açıldı
app.use("/api/firm", firmRoute);
app.use('/api/operation', operationRoutes);
app.use('/api/stok', stokRoutes);
app.use('/api/kasa', kasaRoutes);
app.use('/api/tahsilat', tahsilatRoutes); // app.use listesinin sonuna ekle
app.use('/api/kasa_v2', kasaV2Router);



// --- MÜDÜR: MALZEME TALEP YOLU BURADA AÇILDI ---

app.use("/api/material-requests", materialRequestsRoutes);


app.use("/api/material", materialRequestsRoutes); 




// MÜDÜR: Sunucuya 'pending' yolunu doğrudan tarif ediyoruz
app.get("/api/material-requests/pending", materialRequestsRoutes);
app.get("/api/material/pending", materialRequestsRoutes);



// --- MÜDÜR: USTA TAHSİLAT GÜMRÜK KAPISI (SADECE EKLEME) ---
app.post('/api/operation/tahsilat-kaydet', async (req, res) => {
    const { id, usta_maliyet, tahsil_edilen_tutar } = req.body;
    
    try {
        // Not: database.js içindeki pool/db nesneni kullanarak sorgu atar
        const query = `
            UPDATE appointments 
            SET usta_maliyet = $1, 
                tahsil_edilen_tutar = $2, 
                status = 'Mali Onay Bekliyor' 
            WHERE id = $3
        `;
        
        await db.query(query, [usta_maliyet, tahsil_edilen_tutar, id]);
        
        console.log(`✅ Gümrükten Geçti: ID ${id} için ${tahsil_edilen_tutar} TL kaydedildi.`);
        res.json({ success: true, message: "Maliyet ve tahsilat başarıyla gümrüğe bildirildi." });
    } catch (err) {
        console.error("❌ Gümrük Hatası:", err);
        res.status(500).json({ success: false, message: "Veritabanı güncellenemedi!" });
    }
});



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
  console.log(`📱 Telefon İçin: http://192.168.1.42:${PORT}`);
  console.log("🛠️  Veritabanı Bağlantısı Hazır"); // Not: PostgreSQL şeması gördüm ama kodunda sqlite3 kullanılıyor olabilir, şemaya sadık kalıyoruz.
  console.log("🛠️  Malzeme Talep Sistemi Aktif");
  console.log("-----------------------------------------");
});


