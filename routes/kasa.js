const express = require('express');
const router = express.Router();
const db = require('../database'); 





// --- 1. KASA ÖZETİ VE LİSTESİ (Genel + Günlük Kasa Zırhlı Versiyon) ---
router.get('/all', async (req, res) => {
    try {
        const listeQuery = `
            SELECT 
                k.*,
                CASE 
                    WHEN c.name IS NOT NULL THEN c.name
                    WHEN f.firma_adi IS NOT NULL THEN f.firma_adi
                    WHEN c_app.name IS NOT NULL THEN c_app.name
                    WHEN f_app.firma_adi IS NOT NULL THEN f_app.firma_adi
                    WHEN k.kategori = 'Stok Satışı' THEN 'Hızlı Barkod Satışı'
                    WHEN k.kategori = 'Kasaya Nakit Girişi' THEN 'Banko İşlemi'
                    ELSE 'Sistem İşlemi'
                END as musteri_adi,
                COALESCE(d.brand, app.issue_text, k.kategori) as marka,
                COALESCE(d.model, '') as model
            FROM kasa_islemleri k
            LEFT JOIN services s ON k.servis_no = s.servis_no AND k.servis_no IS NOT NULL
            LEFT JOIN devices d ON s.device_id = d.id AND s.device_id IS NOT NULL
            LEFT JOIN customers c ON s.customer_id = c.id AND s.customer_id IS NOT NULL
            LEFT JOIN firms f ON s.firm_id = f.id AND s.firm_id IS NOT NULL
            LEFT JOIN appointments app ON k.servis_no = app.servis_no AND k.servis_no IS NOT NULL
            LEFT JOIN customers c_app ON app.customer_id = c_app.id AND app.customer_id IS NOT NULL
            LEFT JOIN firms f_app ON app.firm_id = f_app.id AND app.firm_id IS NOT NULL
            ORDER BY k.islem_tarihi DESC
        `;
        const listeResult = await db.query(listeQuery);

        // 🚨 MÜDÜRÜN VİZYONU: HEM GENEL KASAYI HEM GÜNLÜK KASAYI ÇEKİYORUZ!
        const bakiyeQuery = `
            SELECT 
                -- GENEL KASA (Tüm Zamanlar)
                COALESCE(SUM(CASE WHEN islem_yonu = 'GİRİŞ' THEN tutar ELSE 0 END), 0) as genel_giris,
                COALESCE(SUM(CASE WHEN islem_yonu = 'ÇIKIŞ' THEN tutar ELSE 0 END), 0) as genel_cikis,
                
                -- GÜNLÜK KASA (Sadece Bugün)
                COALESCE(SUM(CASE WHEN islem_yonu = 'GİRİŞ' AND DATE(islem_tarihi) = CURRENT_DATE THEN tutar ELSE 0 END), 0) as gunluk_giris,
                COALESCE(SUM(CASE WHEN islem_yonu = 'ÇIKIŞ' AND DATE(islem_tarihi) = CURRENT_DATE THEN tutar ELSE 0 END), 0) as gunluk_cikis
            FROM kasa_islemleri;
        `;
        const bakiyeResult = await db.query(bakiyeQuery);
        const hesap = bakiyeResult.rows[0];

        // Matematiksel Hesaplamalar
        const genel_net = parseFloat(hesap.genel_giris) - parseFloat(hesap.genel_cikis);
        const gunluk_net = parseFloat(hesap.gunluk_giris) - parseFloat(hesap.gunluk_cikis);

        res.json({ 
            success: true, 
            data: listeResult.rows, 
            ozet: {
                genel: {
                    giris: parseFloat(hesap.genel_giris),
                    cikis: parseFloat(hesap.genel_cikis),
                    net: genel_net
                },
                gunluk: {
                    giris: parseFloat(hesap.gunluk_giris),
                    cikis: parseFloat(hesap.gunluk_cikis),
                    net: gunluk_net
                }
            }
        });
    } catch (err) {
        console.error("Kasa Listeleme Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});





// --- 3. CİHAZ ARAMA (Para Girişi Formundaki Radar İçin) ---
router.get('/search-service', async (req, res) => {
    const { servis_no } = req.query;
    try {
        const query = `
            SELECT 
                s.servis_no, 
                s.offer_price as fiyatTeklifi,
                d.brand as marka, 
                d.model,
                -- Seri numarasını sildik, bize hata çıkartıyordu.
                COALESCE(c.name, f.firma_adi, 'Bilinmeyen Müşteri') as musteri_adi
            FROM services s
            LEFT JOIN devices d ON s.device_id = d.id
            LEFT JOIN customers c ON s.customer_id = c.id
            LEFT JOIN firms f ON s.firm_id = f.id
            WHERE s.servis_no = $1
        `;
        const result = await db.query(query, [servis_no]);
        if (result.rows.length > 0) {
            res.json({ success: true, found: true, device: result.rows[0] });
        } else {
            res.json({ success: true, found: false });
        }
    } catch (err) {
        console.error("Cihaz Arama Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});



/*


14041903 WEB KASA ÇIKIŞI BOZULDU
// --- 3. CİHAZ ARAMA (Para Girişi Formundaki Radar İçin) ---
router.get('/search-service', async (req, res) => {
    const { servis_no } = req.query;
    try {
        const query = `
            SELECT 
                s.servis_no, 
                s.offer_price as fiyatTeklifi,
                d.brand as marka, 
                d.model, 
                d.serial_number as seriNo
            FROM services s
            LEFT JOIN devices d ON s.device_id = d.id
            WHERE s.servis_no = $1
        `;
        const result = await db.query(query, [servis_no]);
        if (result.rows.length > 0) {
            res.json({ success: true, found: true, device: result.rows[0] });
        } else {
            res.json({ success: true, found: false });
        }
    } catch (err) {
        console.error("Cihaz Arama Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

*/











// --- KASAYA İŞLEM EKLEME VE STATÜ KAPATMA (TEK VE KESİN GÜÇ) ---
router.post('/add', async (req, res) => {
    // MÜDÜR: Bütün verileri tek bir yerde topladık
    const { islem_yonu, kategori, tutar, aciklama, islem_yapan, baglanti_id, servis_no } = req.body;
    
    try {
        // 🛡️ ANA MOTOR KALKANI (GÜVENLİK DUVARI) 🛡️
        // Para kasaya GİRMEDEN 1 salise önce çalışır! Hangi kapıdan gelirse gelsin buraya toslar.
        if (servis_no && (islem_yonu === 'GİRİŞ' || !islem_yonu)) {
            // Sadece 'services' (Tamir) tablosundaki işleri kontrol eder (Randevuları es geçer)
            const sQuery = await db.query('SELECT id FROM services WHERE servis_no = $1', [servis_no]);
            
            if (sQuery.rows.length > 0) {
                const service_id = sQuery.rows[0].id;

                // Taktığı parçaların GÜNCEL ALIŞ MALİYETİNİ (Depodan) topla
                
                const pQuery = `
                    SELECT SUM(mr.quantity * COALESCE(e.alis_fiyati, 0)) as toplam_maliyet
                    FROM material_requests mr
                    LEFT JOIN envanter e ON TRIM(mr.part_name) = TRIM(e.malzeme_adi) -- MÜDÜR: İŞTE BURASI! Sadece TAM eşleşenleri alacak.
                    WHERE mr.service_id = $1
                `;





                /*
                
                const pQuery = `
                    SELECT SUM(mr.quantity * COALESCE(e.alis_fiyati, 0)) as toplam_maliyet
                    FROM material_requests mr
                    LEFT JOIN envanter e ON TRIM(mr.part_name) ILIKE '%' || TRIM(e.malzeme_adi) || '%'
                    WHERE mr.service_id = $1
                `;

                */




                const pResult = await db.query(pQuery, [service_id]);
                const maliyet = parseFloat(pResult.rows[0].toplam_maliyet || 0);
                const girilenTutar = parseFloat(tutar || 0);

                // 🚨 ZARARINA İŞLEMSE KASAYI KİLİTLE VE İŞLEMİ REDDET!
                if (maliyet > girilenTutar) {
                    return res.json({ 
                        success: false, 
                        // Telefonda direkt "HATA" başlığıyla bu mesaj fırlayacak:
                        error: `🚨 SİSTEM REDDETTİ!\n\nTahsil Etmek İstediğiniz: ${girilenTutar.toFixed(2)} ₺\nKullanılan Parça Maliyeti: ${maliyet.toFixed(2)} ₺\n\nBu işlem dükkanı zarara soktuğu için kasa girişi YAPILAMAZ ve cihaz 'Teslim Edildi' yapılamaz!` 
                    });
                }
            }
        }

        // 1. ADIM: Kalkanı geçtiyse Parayı Kasaya Mühürle
        const yon = islem_yonu || 'GİRİŞ'; 
        
        const kasaQuery = `
            INSERT INTO kasa_islemleri (islem_yonu, kategori, tutar, aciklama, islem_yapan, baglanti_id, servis_no, islem_tarihi)
            VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
            RETURNING *;
        `;
        const result = await db.query(kasaQuery, [
            yon, 
            kategori || 'Kasaya Nakit Girişi', 
            tutar, 
            aciklama, 
            islem_yapan || 'Admin', 
            baglanti_id || null, 
            servis_no || null
        ]);

        // 2. ADIM: İŞTE HAYATİ DOKUNUŞ! 
        // Eğer bu para bir servis numarasından geldiyse, o işi 'Teslim Edildi' yapıyoruz.
        if (servis_no) {
            // Hem randevular tablosunu hem de servis tablosunu kapatıyoruz ki hiçbir yerde asılı kalmasın!
            await db.query(`UPDATE appointments SET status = 'Teslim Edildi' WHERE servis_no = $1`, [servis_no]);
            await db.query(`UPDATE services SET status = 'Teslim Edildi' WHERE servis_no = $1`, [servis_no]);
            
            console.log(`✅ [OTOMASYON] ${servis_no} nolu iş Teslim Edildi olarak kapatıldı!`);
        }

        res.json({ 
            success: true, 
            message: 'Para kasaya girdi ve iş ekrandan düşürüldü.', 
            data: result.rows[0] 
        });

    } catch (err) {
        console.error("Kasa İşlem Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});


// --- MÜDÜR: RANDEVU ARAMA MOTORU (SÜTUN HATASI GİDERİLDİ) ---
router.get('/search-randevu', async (req, res) => {
    const { servis_no } = req.query;
    try {
        const query = `
            SELECT 
                a.id, 
                a.servis_no, 
                COALESCE(c.name, f.firma_adi, 'Bilinmeyen Müşteri') as musteri_adi,
                -- MÜDÜR: parca_cihaz yoksa issue_text'i cihaz_turu olarak alıyoruz
                COALESCE(a.issue_text, 'Randevu İşlemi') as cihaz_turu,
                'Randevu' as marka,
                '' as model,
                a.status,
                a.tahsil_edilen_tutar as "fiyatTeklifi"
            FROM appointments a
            LEFT JOIN customers c ON a.customer_id = c.id
            LEFT JOIN firms f ON a.firm_id = f.id
            WHERE TRIM(a.servis_no) = TRIM($1) 
            LIMIT 1
        `;
        const result = await db.query(query, [servis_no]);
        
        if (result.rows.length > 0) {
            res.json({ success: true, found: true, device: result.rows[0] });
        } else {
            res.json({ success: true, found: false });
        }
    } catch (err) { 
        console.error("HATA:", err.message);
        res.status(500).json({ success: false, error: err.message }); 
    }
});



// --- 🚨 MÜDÜRÜN ÖZEL OPERASYON ROTASI: SADECE STATÜ İPTAL EDER, PARAYA DOKUNMAZ ---
router.post('/iptal-et', async (req, res) => {
    const { servis_no } = req.body;
    try {
        if (servis_no) {
            // Sadece statüleri günceller, kasa hesabını bozmaz!
            await db.query(`UPDATE appointments SET status = 'İptal Edildi' WHERE servis_no = $1`, [servis_no]);
            await db.query(`UPDATE services SET status = 'İptal Edildi' WHERE servis_no = $1`, [servis_no]);
            console.log(`✅ [İADE OPERASYONU] ${servis_no} nolu işin statüsü İptal Edildi yapıldı.`);
        }
        res.json({ success: true });
    } catch (err) {
        console.error("İptal Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});








module.exports = router;