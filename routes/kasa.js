const express = require('express');
const router = express.Router();
const db = require('../database'); 




// --- 1. KASA ÖZETİ VE LİSTESİ (Tam Uyumlu ve Akıllı Versiyon) ---
router.get('/all', async (req, res) => {
    try {
        const listeQuery = `
            SELECT 
                k.*,
                CASE 
                    -- 1. ÖNCE TAMİR (SERVICES) MÜŞTERİSİNİ ARA
                    WHEN c.name IS NOT NULL THEN c.name
                    WHEN f.firma_adi IS NOT NULL THEN f.firma_adi
                    
                    -- 2. BULAMAZSA RANDEVU (APPOINTMENTS) MÜŞTERİSİNİ ARA
                    WHEN c_app.name IS NOT NULL THEN c_app.name
                    WHEN f_app.firma_adi IS NOT NULL THEN f_app.firma_adi
                    
                    -- 3. EĞER BARKOD SATIŞI İSE BUNU YAZ
                    WHEN k.kategori = 'Stok Satışı' THEN 'Hızlı Barkod Satışı'
                    
                    -- 4. EĞER KASAYA NAKİT GİRİŞİ İSE BUNU YAZ
                    WHEN k.kategori = 'Kasaya Nakit Girişi' THEN 'Banko İşlemi'
                    
                    -- 🚨 MÜDÜRÜN İSTEDİĞİ GELECEK REZERVASYONU (Sonradan eklenecekler için)
                    -- Aşağıdaki satırı kopyalayıp istediğin kadar yeni kural ekleyebilirsin:
                    WHEN k.kategori = 'Yeni Bir Kategori' THEN 'Dördüncü Yeni Bilgi'
                    
                    -- HİÇBİRİNE UYMAZSA STANDART YAZI
                    ELSE 'Sistem İşlemi'
                END as musteri_adi,
                
                -- Cihaz Markası veya Kategori
                COALESCE(d.brand, app.issue_text, k.kategori) as marka,
                COALESCE(d.model, '') as model
            FROM kasa_islemleri k
            
            -- TAMİR BAĞLANTILARI
            LEFT JOIN services s ON k.servis_no = s.servis_no AND k.servis_no IS NOT NULL
            LEFT JOIN devices d ON s.device_id = d.id AND s.device_id IS NOT NULL
            LEFT JOIN customers c ON s.customer_id = c.id AND s.customer_id IS NOT NULL
            LEFT JOIN firms f ON s.firm_id = f.id AND s.firm_id IS NOT NULL
            
            -- RANDEVU BAĞLANTILARI (Randevu isimleri burdan gelecek)
            LEFT JOIN appointments app ON k.servis_no = app.servis_no AND k.servis_no IS NOT NULL
            LEFT JOIN customers c_app ON app.customer_id = c_app.id AND app.customer_id IS NOT NULL
            LEFT JOIN firms f_app ON app.firm_id = f_app.id AND app.firm_id IS NOT NULL
            
            ORDER BY k.islem_tarihi DESC
        `;
        const listeResult = await db.query(listeQuery);

        const bakiyeQuery = `
            SELECT 
                COALESCE(SUM(CASE WHEN islem_yonu = 'GİRİŞ' THEN tutar ELSE 0 END), 0) as toplam_giris,
                COALESCE(SUM(CASE WHEN islem_yonu = 'ÇIKIŞ' THEN tutar ELSE 0 END), 0) as toplam_cikis
            FROM kasa_islemleri;
        `;
        const bakiyeResult = await db.query(bakiyeQuery);
        const hesap = bakiyeResult.rows[0];
        const net_bakiye = parseFloat(hesap.toplam_giris) - parseFloat(hesap.toplam_cikis);

        res.json({ 
            success: true, 
            data: listeResult.rows, 
            ozet: {
                toplam_giris: parseFloat(hesap.toplam_giris),
                toplam_cikis: parseFloat(hesap.toplam_cikis),
                net_bakiye: net_bakiye 
            }
        });
    } catch (err) {
        console.error("Kasa Listeleme Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});







/*
// --- 1. KASA ÖZETİ VE LİSTESİ (Tam Uyumlu Versiyon) ---
router.get('/all', async (req, res) => {
    try {
        const listeQuery = `
            SELECT 
                k.*,
                -- Eğer servis numarası varsa müşteriyi bul, yoksa 'Barkod Satışı' yaz
                COALESCE(c.name, f.firma_adi, 'Barkod Satışı') as musteri_adi,
                -- Eğer cihaz varsa markasını bul, yoksa kategoriyi yaz
                COALESCE(d.brand, k.kategori) as marka,
                COALESCE(d.model, '') as model
            FROM kasa_islemleri k
            -- LEFT JOIN'ler kalsın ama servis_no NULL ise sorun çıkarmasın
            LEFT JOIN services s ON k.servis_no = s.servis_no AND k.servis_no IS NOT NULL
            LEFT JOIN devices d ON s.device_id = d.id AND s.device_id IS NOT NULL
            LEFT JOIN customers c ON s.customer_id = c.id AND s.customer_id IS NOT NULL
            LEFT JOIN firms f ON s.firm_id = f.id AND s.firm_id IS NOT NULL
            ORDER BY k.islem_tarihi DESC
        `;
        const listeResult = await db.query(listeQuery);

        const bakiyeQuery = `
            SELECT 
                COALESCE(SUM(CASE WHEN islem_yonu = 'GİRİŞ' THEN tutar ELSE 0 END), 0) as toplam_giris,
                COALESCE(SUM(CASE WHEN islem_yonu = 'ÇIKIŞ' THEN tutar ELSE 0 END), 0) as toplam_cikis
            FROM kasa_islemleri;
        `;
        const bakiyeResult = await db.query(bakiyeQuery);
        const hesap = bakiyeResult.rows[0];
        const net_bakiye = parseFloat(hesap.toplam_giris) - parseFloat(hesap.toplam_cikis);

        res.json({ 
            success: true, 
            data: listeResult.rows, 
            ozet: {
                toplam_giris: parseFloat(hesap.toplam_giris),
                toplam_cikis: parseFloat(hesap.toplam_cikis),
                net_bakiye: net_bakiye 
            }
        });
    } catch (err) {
        console.error("Kasa Listeleme Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

*/




/*
// burası tüm ödemelerin çekildiği yer eski kodu kasaya eklemek için kaldırık eskiden hem randevu hemde servis içim mükemmel çalışıyordu.// --- 1. KASA ÖZETİ VE LİSTESİ (Hatalı sütun kaldırıldı) ---
router.get('/all', async (req, res) => {
    try {
        const listeQuery = `
            SELECT 
                k.*,
                COALESCE(c.name, f.firma_adi) as musteri_adi,
                d.brand as marka,
                d.model as model
            FROM kasa_islemleri k
            LEFT JOIN services s ON k.servis_no = s.servis_no
            LEFT JOIN devices d ON s.device_id = d.id
            LEFT JOIN customers c ON s.customer_id = c.id
            LEFT JOIN firms f ON s.firm_id = f.id
            ORDER BY k.islem_tarihi DESC
        `;
        const listeResult = await db.query(listeQuery);

        const bakiyeQuery = `
            SELECT 
                COALESCE(SUM(CASE WHEN islem_yonu = 'GİRİŞ' THEN tutar ELSE 0 END), 0) as toplam_giris,
                COALESCE(SUM(CASE WHEN islem_yonu = 'ÇIKIŞ' THEN tutar ELSE 0 END), 0) as toplam_cikis
            FROM kasa_islemleri;
        `;
        const bakiyeResult = await db.query(bakiyeQuery);
        const hesap = bakiyeResult.rows[0];
        const net_bakiye = parseFloat(hesap.toplam_giris) - parseFloat(hesap.toplam_cikis);

        res.json({ 
            success: true, 
            data: listeResult.rows, 
            ozet: {
                toplam_giris: parseFloat(hesap.toplam_giris),
                toplam_cikis: parseFloat(hesap.toplam_cikis),
                net_bakiye: net_bakiye 
            }
        });
    } catch (err) {
        console.error("Kasa Listeleme Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

*/




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



// --- KASAYA İŞLEM EKLEME VE STATÜ KAPATMA (TEK VE KESİN GÜÇ) ---
router.post('/add', async (req, res) => {
    // MÜDÜR: Bütün verileri tek bir yerde topladık
    const { islem_yonu, kategori, tutar, aciklama, islem_yapan, baglanti_id, servis_no } = req.body;
    
    try {
        // 1. ADIM: Parayı Kasaya Mühürle
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

module.exports = router;