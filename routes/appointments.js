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

// --- 2. RANDEVU EKLEME (8 SÜTUN 8 DEĞER - KARAKUTU) ---
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

// --- 3. RANDEVU LİSTESİ (TAKİP EKRANI) ---
router.get("/liste/aktif", async (req, res) => {
    try {
        const query = `
            SELECT 
                a.id, a.servis_no, a.appointment_date, a.appointment_time, a.issue_text, a.status,
                COALESCE(c.name, f.firma_adi) as customer_name, 
                COALESCE(c.phone, f.telefon) as customer_phone
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id
            WHERE a.status NOT IN ('İptal Edildi', 'İptal', 'Pasif')
            ORDER BY a.servis_no DESC
        `;
        const result = await db.query(query);
        res.json(result.rows);
    } catch (err) {
        console.error("🚨 Liste Hatası:", err.message);
        res.status(500).json({ error: "Liste çekilemedi" });
    }
});

// --- 4. İPTAL MOTORU (EK OLARAK EKLEDİM) ---
router.put("/iptal/:id", async (req, res) => {
    const { id } = req.params;
    try {
        await db.query("UPDATE appointments SET status = 'İptal Edildi' WHERE id = $1", [id]);
        res.status(200).json({ success: true, message: "Randevu iptal edildi" });
    } catch (err) {
        res.status(500).json({ error: "İptal Hatası" });
    }
});

// --- 5. USTA ÖZEL LİSTESİ (EK OLARAK EKLEDİM) ---
router.get("/usta/:usta_adi", async (req, res) => {
    const usta_adi = req.params.usta_adi;
    try {
        const query = `
            SELECT a.id, a.appointment_date, a.appointment_time, a.issue_text, a.status,
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
        res.status(500).json({ success: false });
    }
});

// --- MÜDÜR: ÇAKIŞMA KONTROLÜ (DÜZELTİLMİŞ HALİ) ---
router.get("/check-conflict", async (req, res) => {
  const { date, time } = req.query;
  try {
    // MÜDÜR: Veritabanındaki gerçek sütun isimlerini (appointment_date, appointment_time) buraya yazdım.
    const query = `
      SELECT id FROM appointments 
      WHERE appointment_date = $1 AND appointment_time = $2
    `;
    const result = await db.query(query, [date, time]);

    // Eğer o tarih ve saatte kayıt varsa isOccupied: true döner
    res.json({ isOccupied: result.rowCount > 0 });
  } catch (err) {
    console.error("ÇAKIŞMA SORGUSU HATASI:", err.message);
    res.status(500).json({ error: err.message });
  }
});






module.exports = router;