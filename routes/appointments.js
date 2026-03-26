const express = require('express');
const router = express.Router();
const db = require('../database');

// --- 1. REHBER SORGULAMA (HİBRİT) ---
router.get("/search-customer", async (req, res) => {
    const { phone } = req.query;
    if (!phone) return res.status(400).json({ success: false });

    try {
        const query = `
            SELECT * FROM (
                SELECT id, name, phone, 'bireysel' as tip FROM customers
                UNION ALL
                SELECT id, firma_adi as name, telefon as phone, 'firma' as tip FROM firms
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

// --- 3. RANDEVU LİSTESİ (SÜZGEÇ STANDARTLAŞTIRILDI) ---
<<<<<<< HEAD
// --- 3. RANDEVU LİSTESİ (HATASIZ VE ZIRHLI VERSİYON) ---
=======
>>>>>>> 2aea985ecbaf54b4c81b26198c61d3e124edf943
router.get("/liste/aktif", async (req, res) => {
    try {
        const query = `
            SELECT 
                a.id, 
                a.servis_no, 
                a.appointment_date, 
                a.appointment_time, 
<<<<<<< HEAD
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
                -- MÜŞTERİ BİLGİLERİ
                COALESCE(c.name, f.firma_adi, 'İsimsiz Müşteri') as customer_name,
                COALESCE(c.phone, f.telefon, '') as customer_phone
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id
            WHERE a.status NOT IN ('İptal Edildi', 'Kapatıldı', 'Pasif')
            ORDER BY a.servis_no DESC;
=======
                a.status,
                a.assigned_usta,
                TRIM(SPLIT_PART(a.issue_text, '🖊️ CİHAZ:', 1)) AS parca_adres,
                TRIM(SPLIT_PART(SPLIT_PART(a.issue_text, '🖊️ CİHAZ:', 2), '📝 NOT:', 1)) AS parca_cihaz,
                TRIM(SPLIT_PART(a.issue_text, '📝 NOT:', 2)) AS parca_not,
                a.issue_text,
                COALESCE(c.name, f.firma_adi) as customer_name, 
                COALESCE(c.phone, f.telefon) as customer_phone
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id
            -- MÜDÜR: İptal Edildi ve Kapatıldı olanlar listeye girmez
            WHERE a.status NOT IN ('İptal Edildi', 'Kapatıldı', 'Pasif')
            ORDER BY a.servis_no DESC
>>>>>>> 2aea985ecbaf54b4c81b26198c61d3e124edf943
        `;
        const result = await db.query(query);
        res.json(result.rows);
    } catch (err) {
        console.error("🚨 Liste Hatası:", err.message);
        res.status(500).json({ error: "Liste çekilemedi" });
    }
});



<<<<<<< HEAD
=======
// --- 3.1 BANKO ÖZEL: TAHSİLAT LİSTESİ (GÜNCELLENDİ) ---
router.get("/liste/tahsilat", async (req, res) => {
    try {
        const query = `
            SELECT 
                a.*, 
                -- MÜDÜRÜM: İşte o altın dokunuş burası!
                -- Önce usta ekranındaki hesaplanmış fiyata (1499) bakıyoruz, 
                -- o boşsa ham fiyata (999) bakıyoruz.
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






















/*
    // --- 3.1 BANKO ÖZEL: TAHSİLAT LİSTESİ (Sadece Tahsilat Ekranı İçin) ---
// Müdürüm: Bu rota yenidir, eskisine dokunmaz, hiçbir şeyi bozmaz!
router.get("/liste/tahsilat", async (req, res) => {
    try {
        const query = `
            SELECT 
                a.*, 
                a.price as usta_fiyati, -- Parayı burada özel isimle alıyoruz
                COALESCE(c.name, f.firma_adi) as customer_name
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id
            WHERE a.status = 'Mali Onay Bekliyor' -- Sadece parası girilmişleri getir
            ORDER BY a.id DESC
        `;
        const result = await db.query(query);
        res.json(result.rows);
    } catch (err) {
        console.error("🚨 Tahsilat Liste Hatası:", err.message);
        res.status(500).json({ error: "Veri çekilemedi" });
    }
});

*/


>>>>>>> 2aea985ecbaf54b4c81b26198c61d3e124edf943


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

<<<<<<< HEAD





// --- 5. USTA ÖZEL LİSTESİ (AJANLI VE ZIRHLI VERSİYON) ---
router.get("/usta/:usta_adi", async (req, res) => {
    const usta_adi = req.params.usta_adi;
    
    // AJAN 1: Telefonda usta adı tam olarak ne geliyor?
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
            
            -- MÜDÜR: İsimlerde boşluk falan varsa diye ILIKE (Esnek Arama) koyduk!
            WHERE TRIM(a.assigned_usta) ILIKE $1 
              AND a.status NOT IN ('İptal Edildi', 'Kapatıldı', 'Teslim Edildi', 'İptal', 'Pasif')
            ORDER BY a.appointment_date ASC
        `;
        
        // Esnek arama parametresi
        const searchParam = `%${usta_adi.trim()}%`;
        const result = await db.query(query, [searchParam]);
        
        // AJAN 2: Veritabanı kaç tane kayıt bulup telefona gönderdi?
        console.log(`🕵️‍♂️ MÜDÜR TAKİP 2: ${usta_adi} için ${result.rowCount} adet randevu telefona gönderildi!`);

        res.json({ success: true, data: result.rows });
    } catch (err) {
        console.error("🚨 Usta Liste Hatası:", err.message);
        res.status(500).json({ success: false });
    }
});



/*

// --- 5. USTA ÖZEL LİSTESİ (TARİH KİLİDİ KIRILDI, İKONLAR DÜZELTİLDİ) ---
router.get("/usta/:usta_adi", async (req, res) => {
    const usta_adi = req.params.usta_adi;
    try {
        const query = `
            SELECT 
                a.id, 
                a.servis_no,
                a.appointment_date, 
                a.appointment_time, 
                a.status,
                a.assigned_usta,
                
                -- MÜDÜR: İkonları Banko ile aynı yaptık (🔧) ki cihaz adı boş gelmesin!
                TRIM(SPLIT_PART(a.issue_text, '🔧 CİHAZ:', 1)) AS parca_adres,
                TRIM(SPLIT_PART(SPLIT_PART(a.issue_text, '🔧 CİHAZ:', 2), '📝 NOT:', 1)) AS parca_cihaz,
                TRIM(SPLIT_PART(a.issue_text, '📝 NOT:', 2)) AS parca_not,
                
                a.issue_text,
                COALESCE(c.name, f.firma_adi) as customer_name, 
                COALESCE(c.phone, f.telefon) as customer_phone
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id
            
            -- MÜDÜR İŞTE SİHİR BURADA: Tarih kısıtlamasını sildik! 
            -- İptal edilen veya Kapatılanlar HARİÇ tüm aktif/bekleyen işler (dünküler dahil) ustaya gider.
            WHERE a.assigned_usta = $1 
              AND a.status NOT IN ('İptal Edildi', 'Kapatıldı', 'Teslim Edildi', 'İptal', 'Pasif')
            ORDER BY a.appointment_date ASC
        `;
        const result = await db.query(query, [usta_adi]);
        res.json({ success: true, data: result.rows });
    } catch (err) {
        console.error("Usta Liste Hatası:", err);
        res.status(500).json({ success: false });
    }
});

diiikkaaat yukarıdaki iyi







=======
>>>>>>> 2aea985ecbaf54b4c81b26198c61d3e124edf943
// --- 5. USTA ÖZEL LİSTESİ (PARÇALAYICI MOTOR EKLENDİ) ---
router.get("/usta/:usta_adi", async (req, res) => {
    const usta_adi = req.params.usta_adi;
    try {
        const query = `
            SELECT 
                a.id, 
                a.servis_no,
                a.appointment_date, 
                a.appointment_time, 
                a.status,
                a.assigned_usta,
                
                -- ADRES, CİHAZ VE NOT AYIKLAMA MOTORU:
                TRIM(SPLIT_PART(a.issue_text, '🖊️ CİHAZ:', 1)) AS parca_adres,
                TRIM(SPLIT_PART(SPLIT_PART(a.issue_text, '🖊️ CİHAZ:', 2), '📝 NOT:', 1)) AS parca_cihaz,
                TRIM(SPLIT_PART(a.issue_text, '📝 NOT:', 2)) AS parca_not,
                
                a.issue_text, -- Orijinal metin her ihtimale karşı dursun
                COALESCE(c.name, f.firma_adi) as customer_name, 
                COALESCE(c.phone, f.telefon) as customer_phone
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id
            WHERE a.assigned_usta = $1 AND a.appointment_date >= CURRENT_DATE
            ORDER BY a.appointment_date ASC
        `;
        const result = await db.query(query, [usta_adi]);
        res.json({ success: true, data: result.rows });
    } catch (err) {
        console.error("Usta Liste Hatası:", err);
        res.status(500).json({ success: false });
    }
});

<<<<<<< HEAD
*/






=======
>>>>>>> 2aea985ecbaf54b4c81b26198c61d3e124edf943

// --- 6. ÇAKIŞMA KONTROLÜ (SÜZGEÇ STANDARTLAŞTIRILDI) ---
router.get("/check-conflict", async (req, res) => {
  const { date, time } = req.query;
  try {
    const query = `
      SELECT id FROM appointments 
      WHERE appointment_date = $1 
        AND appointment_time = $2
        -- MÜDÜR: Sadece 'Beklemede' veya 'İşlem Bekliyor' olanlar yolu tıkar.
        -- İptal Edildi veya Kapatıldı olanlar artık dolu uyarısı vermez!
        AND status NOT IN ('İptal Edildi', 'Kapatıldı', 'Teslim Edildi', 'İptal', 'Pasif')
    `;
    const result = await db.query(query, [date, time]);
    res.json({ isOccupied: result.rowCount > 0 });
  } catch (err) {
    console.error("🚨 ÇAKIŞMA SORGUSU HATASI:", err.message);
    res.status(500).json({ error: err.message });
  }
});

<<<<<<< HEAD


=======
/*
// --- 6. ÇAKIŞMA KONTROLÜ (GÜNCELLENDİ: İPTAL OLANLAR YOLU TIKAMAZ!) ---
router.get("/check-conflict", async (req, res) => {
  const { date, time } = req.query;
  try {
    const query = `
      SELECT id FROM appointments 
      WHERE appointment_date = $1 
        AND appointment_time = $2
        AND status NOT IN ('İptal Edildi', 'İptal', 'Pasif', 'Kapatıldı') -- MÜDÜR: İŞTE O FİLTRE!
    `;
    const result = await db.query(query, [date, time]);
    res.json({ isOccupied: result.rowCount > 0 });
  } catch (err) {
    console.error("🚨 ÇAKIŞMA SORGUSU HATASI:", err.message);
    res.status(500).json({ error: err.message });
  }
});

*/


// 7 BANKO: ONAY ROTASI (GÜNCELLENDİ)
router.post("/finance-approve", async (req, res) => {
    const { id, action } = req.body;
    try {
        if (action === 'yes') {
            // Statüyü 'Kapatıldı' yapıyoruz ki '/liste/tahsilat' sorgusundaki 
            // "WHERE status = 'Mali Onay Bekliyor'" filtresine takılmasın ve listeden düşsün.
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









/*
>>>>>>> 2aea985ecbaf54b4c81b26198c61d3e124edf943
// 7 BANKO: BASİTLEŞTİRİLMİŞ ONAY ROTASI (Mali Tablo Yok, Sadece Statü Değişir)
router.post("/finance-approve", async (req, res) => {
    const { id, action } = req.body;

    try {
        if (action === 'yes') {
            // MÜDÜR: Şimdilik sadece statüyü "Kapatıldı" yapıyoruz ki aktif listeden (ekrandan) düşsün.
            // İleride mali modülü yazdığında o "INSERT INTO kasa..." kodlarını tam buraya eklersin!
            await db.query(`UPDATE appointments SET status = 'Kapatıldı' WHERE id = $1`, [id]);
            
        } else if (action === 'no') {
            // "Hayır" denirse statüyü "İşlem Bekliyor" yap (Ekranda sarı kutuyla asılı kalır)
            await db.query(`UPDATE appointments SET status = 'İşlem Bekliyor' WHERE id = $1`, [id]);
        }

        res.json({ success: true });
    } catch (error) {
        console.error("Onay Hatası:", error);
        res.status(500).json({ success: false, error: "İşlem kaydedilemedi" });
    }
});

<<<<<<< HEAD
=======
?/

*/

// --- YENİ BÜYÜTEÇ KAPISI (SADECE RANDEVULARA BAKAR) ---
router.get("/search-randevu", async (req, res) => {
    const { servis_no } = req.query;

// MÜDÜR: 1. Ajan (İstek geldi mi?)
    console.log("🛠️ BÜYÜTEÇE BASILDI! Gelen Numara:", servis_no);



    try {
        const query = `
            SELECT 
                a.id,
                a.servis_no,
                COALESCE(f.firma_adi, c.name, 'Bilinmeyen Müşteri') AS musteri_adi,
                'Randevu Geliri Tahsili' AS cihaz_turu,
                a.status,
                -- MÜDÜR: Ustanın kârlı rakamını (1499) burada çeker
                COALESCE(a.tahsil_edilen_tutar, a.price, 0) AS "fiyatTeklifi"
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id 
            WHERE a.servis_no = $1 AND a.status = 'Mali Onay Bekliyor'
            LIMIT 1
        `;
        const result = await db.query(query, [servis_no]);
        
        // MÜDÜR: 2. Ajan (Veritabanı ne buldu?)
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


>>>>>>> 2aea985ecbaf54b4c81b26198c61d3e124edf943




module.exports = router;