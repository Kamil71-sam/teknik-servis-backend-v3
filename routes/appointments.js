const express = require('express');
const router = express.Router();
const db = require('../database');



// --- 1. REHBER SORGULAMA (HİBRİT) ---
router.get("/search-customer", async (req, res) => {
    const { phone } = req.query;
    if (!phone) return res.status(400).json({ success: false });

    try {
        // MÜDÜR: 'address' ve 'adres as address' eklendi! Adres borusu açıldı.
        const query = `
            SELECT * FROM (
                SELECT id, name, phone, 'bireysel' as tip, address FROM customers
                UNION ALL
                SELECT id, firma_adi as name, telefon as phone, 'firma' as tip, adres as address FROM firms
            ) as combined
            WHERE phone = $1
            LIMIT 1
        `;
        const result = await db.query(query, [phone]);
        if (result.rows.length > 0) {
            res.json({ success: true, data: result.rows[0] });
        } else {
            res.json({ success: false, message: "Kayıt bulunamadı" });
        }
    } catch (err) {
        console.error("🚨 Arama Hatası:", err.message);
        res.status(500).json({ success: false, error: "Rehber hatası" });
    }
});


// --- 2. RANDEVU EKLEME (VARSAYILAN STATÜ: 'Beklemede') ---
router.post("/ekle", async (req, res) => {
    const { customer_id, type, date, time, usta, issue } = req.body;
    try {
        const today = new Date();
        const yy = String(today.getFullYear()).slice(-2);
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const dd = String(today.getDate()).padStart(2, '0');
        const prefix = `${yy}${mm}${dd}`;

        const seqQuery = `
            SELECT MAX(servis_no) as max_no FROM (
                SELECT servis_no FROM appointments WHERE servis_no LIKE $1
                UNION ALL
                SELECT servis_no FROM services WHERE servis_no LIKE $1
            ) as combined
        `;
        const seqResult = await db.query(seqQuery, [`${prefix}%`]);
        let nextSeqNum = 1;
        if (seqResult.rows.length > 0 && seqResult.rows[0].max_no) {
            nextSeqNum = parseInt(seqResult.rows[0].max_no.substring(6), 10) + 1;
        }
        const servisNo = `${prefix}${String(nextSeqNum).padStart(2, '0')}`;

        const insertQuery = `
            INSERT INTO appointments (
                customer_id, firm_id, appointment_date, appointment_time, 
                assigned_usta, issue_text, servis_no, status
            ) 
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        `;
        
        // MÜDÜR: Statü burada 'Beklemede' olarak standart açılıyor
        const values = [
            type === 'bireysel' ? customer_id : null, 
            type === 'firma' ? customer_id : null,
            date, time, usta, issue, servisNo, 'Beklemede'
        ];

        await db.query(insertQuery, values);
        console.log(`✅ KAYIT BAŞARILI: ${servisNo}`);
        res.json({ success: true, message: "Randevu oluşturuldu", servis_no: servisNo });

    } catch (err) {
        console.error("🚨 Ekleme Hatası:", err.message);
        res.status(500).json({ success: false, error: "Veritabanı kayıt hatası" });
    }
});

// --- 3. RANDEVU LİSTESİ (HATASIZ VE ZIRHLI VERSİYON) ---
router.get("/liste/aktif", async (req, res) => {
    try {
        const query = `
            SELECT 
                a.id, 
                a.servis_no, 
                a.appointment_date, 
                a.appointment_time, 
                a.status, 
                a.assigned_usta,
                -- CİHAZ PARÇALAMA
                TRIM(SPLIT_PART(a.issue_text, '🔧 CİHAZ:', 1)) AS parca_adres,
                TRIM(SPLIT_PART(SPLIT_PART(a.issue_text, '🔧 CİHAZ:', 2), '📝 NOT:', 1)) AS parca_cihaz,
                TRIM(SPLIT_PART(a.issue_text, '📝 NOT:', 2)) AS parca_not,
                a.issue_text,
                -- PARALAR (PGAdmin'deki 666 TL'yi getiren kısım)
                a.price, 
                a.tahsil_edilen_tutar,
                COALESCE(a.tahsil_edilen_tutar, a.price, 0) as usta_fiyati, 
                -- MÜDÜRÜ BİLGİLERİ
                COALESCE(c.name, f.firma_adi, 'İsimsiz Müşteri') as customer_name,
                COALESCE(c.phone, f.telefon, '') as customer_phone
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id
            WHERE a.status NOT IN ('İptal Edildi', 'Kapatıldı', 'Pasif')
            ORDER BY a.servis_no DESC;
               
        `;
        const result = await db.query(query);
        res.json(result.rows);
    } catch (err) {
        console.error("🚨 Liste Hatası:", err.message);
        res.status(500).json({ error: "Liste çekilemedi" });
    }
});

// --- 3.1 BANKO ÖZEL: TAHSİLAT LİSTESİ (GÜNCELLENDİ) ---
router.get("/liste/tahsilat", async (req, res) => {
    try {
        const query = `
            SELECT 
                a.*, 
                -- MÜDÜRÜM: İşte o altın dokunuş burası!
                COALESCE(a.tahsil_edilen_tutar, a.price, 0) as usta_fiyati,
                COALESCE(c.name, f.firma_adi) as customer_name
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id
            WHERE a.status = 'Mali Onay Bekliyor'
            ORDER BY a.id DESC
        `;
        const result = await db.query(query);
        res.json(result.rows);
    } catch (err) {
        console.error("🚨 Tahsilat Liste Hatası:", err.message);
        res.status(500).json({ error: "Veri çekilemedi" });
    }
});

// --- 4. İPTAL MOTORU ---
router.put("/iptal/:id", async (req, res) => {
    const { id } = req.params;
    try {
        await db.query("UPDATE appointments SET status = 'İptal Edildi' WHERE id = $1", [id]);
        res.status(200).json({ success: true, message: "Randevu iptal edildi" });
    } catch (err) {
        res.status(500).json({ error: "İptal Hatası" });
    }
});

// --- 5. USTA ÖZEL LİSTESİ (AJANLI VE ZIRHLI VERSİYON) ---
router.get("/usta/:usta_adi", async (req, res) => {
    const usta_adi = req.params.usta_adi;
    console.log("🕵️‍♂️ MÜDÜR TAKİP 1: Gelen Usta Adı ->", usta_adi); 

    try {
        const query = `
            SELECT 
                a.id, 
                a.servis_no,
                a.appointment_date, 
                a.appointment_time, 
                a.status,
                a.assigned_usta,
                TRIM(SPLIT_PART(a.issue_text, '🔧 CİHAZ:', 1)) AS parca_adres,
                TRIM(SPLIT_PART(SPLIT_PART(a.issue_text, '🔧 CİHAZ:', 2), '📝 NOT:', 1)) AS parca_cihaz,
                TRIM(SPLIT_PART(a.issue_text, '📝 NOT:', 2)) AS parca_not,
                a.issue_text,
                COALESCE(c.name, f.firma_adi) as customer_name, 
                COALESCE(c.phone, f.telefon) as customer_phone
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id
            WHERE TRIM(a.assigned_usta) ILIKE $1 
              AND a.status NOT IN ('İptal Edildi', 'Kapatıldı', 'Teslim Edildi', 'İptal', 'Pasif')
            ORDER BY a.appointment_date ASC
        `;
        
        const searchParam = `%${usta_adi.trim()}%`;
        const result = await db.query(query, [searchParam]);
        console.log(`🕵️‍♂️ MÜDÜR TAKİP 2: ${usta_adi} için ${result.rowCount} adet randevu telefona gönderildi!`);

        res.json({ success: true, data: result.rows });
    } catch (err) {
        console.error("🚨 Usta Liste Hatası:", err.message);
        res.status(500).json({ success: false });
    }
});

// --- 6. ÇAKIŞMA KONTROLÜ (SÜZGEÇ STANDARTLAŞTIRILDI) ---
router.get("/check-conflict", async (req, res) => {
  const { date, time } = req.query;
  try {
    const query = `
      SELECT id FROM appointments 
      WHERE appointment_date = $1 
        AND appointment_time = $2
        AND status NOT IN ('İptal Edildi', 'Kapatıldı', 'Teslim Edildi', 'İptal', 'Pasif')
    `;
    const result = await db.query(query, [date, time]);
    res.json({ isOccupied: result.rowCount > 0 });
  } catch (err) {
    console.error("🚨 ÇAKIŞMA SORGUSU HATASI:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// 7 BANKO: ONAY ROTASI (GÜNCELLENDİ)
router.post("/finance-approve", async (req, res) => {
    const { id, action } = req.body;
    try {
        if (action === 'yes') {
            await db.query(`UPDATE appointments SET status = 'Kapatıldı' WHERE id = $1`, [id]);
        } else if (action === 'no') {
            await db.query(`UPDATE appointments SET status = 'İşlem Bekliyor' WHERE id = $1`, [id]);
        }
        res.json({ success: true });
    } catch (error) {
        console.error("Onay Hatası:", error);
        res.status(500).json({ success: false });
    }
});

// --- YENİ BÜYÜTEÇ KAPISI (SADECE RANDEVULARA BAKAR) ---
router.get("/search-randevu", async (req, res) => {
    const { servis_no } = req.query;
    console.log("🛠️ BÜYÜTEÇE BASILDI! Gelen Numara:", servis_no);

    try {
        const query = `
            SELECT 
                a.id,
                a.servis_no,
                COALESCE(f.firma_adi, c.name, 'Bilinmeyen Müşteri') AS musteri_adi,
                'Randevu Geliri Tahsili' AS cihaz_turu,
                a.status,
                COALESCE(a.tahsil_edilen_tutar, a.price, 0) AS "fiyatTeklifi"
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id 
            WHERE a.servis_no = $1 AND a.status = 'Mali Onay Bekliyor'
            LIMIT 1
        `;
        const result = await db.query(query, [servis_no]);
        console.log("🛠️ SQL NE BULDU?:", result.rows)

        if (result.rows.length > 0) {
            res.json({ success: true, found: true, device: result.rows[0] });
        } else {
            res.json({ success: true, found: false });
        }
    } catch (err) {
        console.error("🚨 Randevu Arama Hatası:", err);
        res.status(500).json({ success: false });
    }
});


// 🚨🚨 MÜDÜRÜN YENİ DASHBOARD MOTORU (SİMİTİ VE MOR BUTONU BESLER) 🚨🚨
router.get("/pending-confirmations", async (req, res) => {
    try {
        // 1. YARIN ARANACAKLAR (Mor butonun sayısı için)
        // CURRENT_DATE + 1 ile veritabanından kesin olarak yarının tarihi bulunur.
        const yarinQuery = `
            SELECT id FROM appointments 
            WHERE CAST(appointment_date AS DATE) = CURRENT_DATE + INTERVAL '1 day' 
            AND status NOT IN ('İptal Edildi', 'Kapatıldı', 'Pasif', 'Teslim Edildi')
        `;
        const yarinResult = await db.query(yarinQuery);

        // 2. KALIN SİMİT İÇİN TOPLAM AKTİF RANDEVULAR (Mor dilim için)
        const toplamQuery = `
            SELECT COUNT(*) FROM appointments 
            WHERE status NOT IN ('İptal Edildi', 'Kapatıldı', 'Pasif', 'Teslim Edildi')
        `;
        const toplamResult = await db.query(toplamQuery);

        res.json({ 
            success: true, 
            data: yarinResult.rows, // Yarın aranacaklar listesi (Butona sayısını basar)
            toplam_aktif: parseInt(toplamResult.rows[0].count) // Simitteki mor dilimi besler
        });
    } catch (err) {
        console.error("🚨 Dashboard Teyit Özet Hatası:", err.message);
        res.status(500).json({ success: false });
    }
});


// 🚨 YENİ EKLENEN ARŞİV (GEÇMİŞ) ROTASI - ÇALIŞAN HİÇBİR KODU BOZMAZ!
router.get("/liste/gecmis", async (req, res) => {
    try {
        const query = `
            SELECT 
                a.id, 
                a.servis_no, 
                a.appointment_date, 
                a.appointment_time, 
                a.status, 
                a.assigned_usta,
                a.yonetici_notu, -- MÜDÜR: YENİ NOT SÜTUNU EKLENDİ!
                TRIM(SPLIT_PART(a.issue_text, '🔧 CİHAZ:', 1)) AS parca_adres,
                TRIM(SPLIT_PART(SPLIT_PART(a.issue_text, '🔧 CİHAZ:', 2), '📝 NOT:', 1)) AS parca_cihaz,
                TRIM(SPLIT_PART(a.issue_text, '📝 NOT:', 2)) AS parca_not,
                a.issue_text,
                a.price, 
                a.tahsil_edilen_tutar,
                COALESCE(a.tahsil_edilen_tutar, a.price, 0) as usta_fiyati, 
                COALESCE(c.name, f.firma_adi, 'İsimsiz Müşteri') as customer_name,
                COALESCE(c.phone, f.telefon, '') as customer_phone
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id
            WHERE a.status IN ('Teslim Edildi', 'İptal', 'İptal Edildi')
            ORDER BY a.appointment_date DESC, a.appointment_time DESC;
        `;
        const result = await db.query(query);
        res.json({ success: true, data: result.rows });
    } catch (err) {
        console.error("🚨 Geçmiş Liste Hatası:", err.message);
        res.status(500).json({ error: "Geçmiş liste çekilemedi" });
    }
});


// --- YÖNETİCİ HIZLI NOT KAYDETME ENDPOINT'İ ---
router.put("/:id/hizli-not", async (req, res) => {
    const { id } = req.params;
    const { yonetici_notu } = req.body;

    try {
        const query = 'UPDATE appointments SET yonetici_notu = $1 WHERE id = $2';
        await db.query(query, [yonetici_notu, id]);

        console.log(`✅ NOT EKLENDİ (ID: ${id}): ${yonetici_notu}`);
        res.status(200).json({ success: true, message: 'Not başarıyla kaydedildi.' });
    } catch (err) {
        console.error("🚨 Not kaydetme hatası:", err.message);
        res.status(500).json({ success: false, message: 'Not güncellenemedi.' });
    }
});




module.exports = router;