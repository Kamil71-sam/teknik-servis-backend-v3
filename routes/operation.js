const express = require('express');
const router = express.Router();
const db = require('../database'); // Veritabanı bağlantı yolun

// 1. BANKO: Yarınki Teyit Bekleyenleri Getir
router.get('/pending-confirmations', async (req, res) => {
    try {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        const tomorrowStr = tomorrow.toISOString().split('T')[0];

        const query = `
            SELECT a.id, a.servis_no, 
                   COALESCE(c.name, f.firma_adi, 'Bilinmeyen') as musteri_adi, 
                   a.appointment_time as saat, a.appointment_date as tarih
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id
            WHERE a.appointment_date = $1 
            AND a.is_confirmed = false 
            AND a.status NOT IN ('İptal', 'Pasif')
        `;
        const result = await db.query(query, [tomorrowStr]);
        res.json({ success: true, data: result.rows });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

// 2. BANKO: Randevu Teyit Et
router.patch('/confirm-appointment/:id', async (req, res) => {
    const { id } = req.params;
    try {
        await db.query('UPDATE appointments SET is_confirmed = true WHERE id = $1', [id]);
        res.json({ success: true, message: "Teyit alındı." });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});




// 3. USTA: Kendine Atanan İşleri Getir (GÜMRÜK KAPISI AÇILDI)
router.get('/usta-jobs/:ustaName', async (req, res) => {
    const { ustaName } = req.params;
    try {
        const query = `
            SELECT 
                a.id, 
                a.servis_no, 
                COALESCE(c.name, f.firma_adi, 'Müşteri Bilgisi Yok') as musteri_adi, 
                a.appointment_date::text as tarih, 
                a.appointment_time::text as saat,
                a.issue_text as detay,
                a.status
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id
            WHERE a.assigned_usta = $1 
            -- MÜDÜR: 'İşlem Bekliyor' statüsünü listeye ekledik. Başka hiçbir yeri bozmaz!
            AND a.status IN ('Beklemede', 'Devam Ediyor', 'İşlem Bekliyor')
            ORDER BY a.appointment_date ASC, a.appointment_time ASC;
        `;
        const result = await db.query(query, [ustaName]);
        res.json({ success: true, data: result.rows });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});




// 4. USTA: İşi Bitir (MÜDÜR: Burası artık 'Mali Onay Bekliyor' yapacak!)
router.patch('/complete-job/:id', async (req, res) => {
    const { id } = req.params;
    const { price, usta_notu } = req.body;
    try {
        const query = `
            UPDATE appointments 
            SET price = $1, 
                usta_notu = $2, 
                status = 'Mali Onay Bekliyor' -- MÜDÜR: 'Tamamlandı' yazısını sildik, gümrüğe çektik!
            WHERE id = $3
        `;
        await db.query(query, [price, usta_notu, id]);
        
        console.log(`✅ [USTA BİTİRDİ] ID: ${id} - Fiyat: ${price} TL - Gümrükte Bekliyor.`);
        res.json({ success: true, message: "İşlem gümrüğe (Mali Onaya) gönderildi." });
    } catch (err) {
        console.error("❌ Usta Bitirme Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});




router.get('/usta-stats/:ustaName', async (req, res) => {
    const { ustaName } = req.params;
    
    // MÜDÜR: Terminale ilk sinyali çakıyoruz
    console.log("-----------------------------------------");
    console.log("🔍 DASHBOARD İSTEĞİ GELDİ!");
    console.log("👤 Sorgulanan Usta:", ustaName);

    try {
        const query = `
            SELECT 
                COUNT(*)::int as randevu_sayisi
            FROM appointments 
            WHERE assigned_usta = $1 
            AND status IN ('Beklemede', 'Devam Ediyor', 'İşlem Bekliyor')
            
        `;
        const result = await db.query(query, [ustaName]);
        
        // MÜDÜR: SQL'den o an ne geliyorsa terminalde göreceğiz
        const count = result.rows[0].randevu_sayisi || 0;
        console.log("📊 SQL'DEN DÖNEN RAKAM:", count);
        console.log("-----------------------------------------");

        res.json({ 
            success: true, 
            stats: {
                randevu: count
            } 
        });
    } catch (err) {
        console.error("❌ BACKEND HATASI:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});


// 6. BANKO: Randevu Finans Onayı (Gelir Ekleme ve Teslim Edildiye Çekme)
router.post('/finance-approve', async (req, res) => {
    const { id, action } = req.body; 

    try {
        // --- Zırhlı İşlem Başlat (Transaction) ---
        await db.query('BEGIN');

        if (action === 'yes') {
            // 1. Randevu bilgilerini çek (Ustanın girdiği price ve usta_notu bilgilerini al)
            const appQuery = "SELECT price, usta_notu, servis_no, assigned_usta FROM appointments WHERE id = $1";
            const appRes = await db.query(appQuery, [id]);
            const row = appRes.rows[0];

            if (!row) {
                await db.query('ROLLBACK');
                return res.status(404).json({ success: false, error: "Randevu bulunamadı!" });
            }

            // 2. Statüyü 'Teslim Edildi' yap (İşlemi kapat)
            await db.query("UPDATE appointments SET status = 'Teslim Edildi' WHERE id = $1", [id]);

            // 3. Kasaya Otomatik Fiş Kes (Randevu Tahsilatı Kategorisiyle)
            const kasaQuery = `
                INSERT INTO kasa_islemleri (islem_yonu, kategori, tutar, aciklama, islem_yapan, servis_no)
                VALUES ('GİRİŞ', 'Randevu Tahsilatı', $1, $2, $3, $4)
            `;
            const aciklama = `Usta: ${row.assigned_usta} | Tahsilat Notu: ${row.usta_notu || 'Not yok'}`;
            
            // Not: Randevu tablosundaki 'price' sütununu tutar olarak alıyoruz
            await db.query(kasaQuery, [row.price || 0, aciklama, 'Banko Onay', row.servis_no]);

            console.log(`✅ [OTOMASYON] ${row.servis_no} nolu randevu kapatıldı, ${row.price} TL kasaya girdi.`);

        } else {
            // Bankocu 'Hayır' derse sadece statüyü 'İşlem Bekliyor' yapıyoruz, kasaya dokunmuyoruz
            await db.query("UPDATE appointments SET status = 'İşlem Bekliyor' WHERE id = $1", [id]);
        }

        await db.query('COMMIT'); // Boruları mühürle
        res.json({ success: true, message: "İşlem başarıyla tamamlandı." });

    } catch (err) {
        await db.query('ROLLBACK'); // Hata varsa hiçbirini yapma, geri sar
        console.error("Finans Onay Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});



module.exports = router;