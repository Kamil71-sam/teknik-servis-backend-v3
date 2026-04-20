const express = require('express');
const router = express.Router();
const db = require('../database'); 

router.get('/detay', async (req, res) => {
    const { servis_no, tip } = req.query;

    if (!servis_no) {
        return res.status(400).json({ success: false, message: "Servis numarası gerekli!" });
    }

    try {
        let faturaVerisi = {
            belgeNo: servis_no,
            tarih: new Date().toLocaleDateString('tr-TR'), 
            musteri: { adi: "", telefon: "", adres: "", vergiNo: "" }, 
            cihaz: { markaModel: "", seriNo: "" },
            kalemler: [],
            toplamlar: { araToplam: 0, kdvToplam: 0, genelToplam: 0 },
            notlar: "" 
        };

        // 🎯 1. TAMİR
        if (tip === 'Tamir' || !tip) {
            const tamirQuery = `
                SELECT s.id as service_id, s.servis_no, s.offer_price as usta_teklifi, s.updated_at as islem_tarihi,
                COALESCE(c.name, f.firma_adi, 'Bilinmeyen Müşteri') as musteri_adi,
                COALESCE(c.phone, f.telefon, '') as telefon, COALESCE(c.address, f.adres, '') as adres,
                f.vergi_no, d.brand, d.model, d.serial_no
                FROM services s
                LEFT JOIN customers c ON s.customer_id = c.id
                LEFT JOIN firms f ON s.firm_id = f.id
                LEFT JOIN devices d ON s.device_id = d.id
                WHERE s.servis_no = $1
            `;
            const tamirResult = await db.query(tamirQuery, [servis_no]);

            if (tamirResult.rows.length > 0) {
                const data = tamirResult.rows[0];
                if (data.islem_tarihi) faturaVerisi.tarih = new Date(data.islem_tarihi).toLocaleDateString('tr-TR');

                faturaVerisi.musteri = { adi: data.musteri_adi, telefon: data.telefon || "-", adres: data.adres || "Belirtilmemiş", vergiNo: data.vergi_no || "" };
                faturaVerisi.cihaz = { markaModel: `${data.brand} ${data.model}`, seriNo: data.serial_no || "-" };
                
                const kasaQuery = `SELECT tutar FROM kasa_islemleri WHERE servis_no = $1 ORDER BY id DESC LIMIT 1`;
                const kasaResult = await db.query(kasaQuery, [servis_no]);
                let gercekKasaTutari = kasaResult.rows.length > 0 ? parseFloat(kasaResult.rows[0].tutar) : parseFloat(data.usta_teklifi || 0);

                let anlasilanTutar = gercekKasaTutari; 
                faturaVerisi.notlar = `İlk Onarım Teklifi: ${parseFloat(data.usta_teklifi || 0).toFixed(2)} ₺`;

                const parcaQuery = `
                    SELECT mr.part_name as ad, mr.quantity as miktar, COALESCE(e.alis_fiyati, 0) as maliyet 
                    FROM material_requests mr
                    LEFT JOIN envanter e ON TRIM(mr.part_name) ILIKE '%' || TRIM(e.malzeme_adi) || '%'
                    WHERE mr.service_id = $1
                `;
                const parcaResult = await db.query(parcaQuery, [data.service_id]);
                
                if (parcaResult.rows.length > 0) {
                    let toplamParcaMaliyeti = parcaResult.rows.reduce((acc, p) => acc + (parseFloat(p.maliyet) * parseFloat(p.miktar)), 0);
                    
                    if (toplamParcaMaliyeti > anlasilanTutar) {
                        return res.json({ 
                            success: false, 
                            message: `🚨 ZARARINA İŞLEM UYARISI!\n\nKasaya Giren Para: ${anlasilanTutar.toFixed(2)} ₺\nParça Maliyeti (Alış): ${toplamParcaMaliyeti.toFixed(2)} ₺\n\nTahsil edilen rakam, parçaların maliyetinden düşük! İşlem durduruldu.` 
                        });
                    }

                    faturaVerisi.kalemler = parcaResult.rows.map(p => ({
                        ad: `${p.ad} (Onarıma dahil edilmiştir)`, miktar: p.miktar, fiyat: 0, kdv: 20, toplam: 0
                    }));
                    faturaVerisi.kalemler.push({ ad: "İşçilik ve Genel Servis Bedeli", miktar: 1, fiyat: anlasilanTutar, kdv: 20, toplam: anlasilanTutar });
                } else {
                    faturaVerisi.kalemler.push({ ad: "İşçilik ve Genel Servis Bedeli", miktar: 1, fiyat: anlasilanTutar, kdv: 20, toplam: anlasilanTutar });
                }
                
                faturaVerisi.toplamlar.genelToplam = anlasilanTutar;

            } else { return res.json({ success: false, message: "Kayıt bulunamadı." }); }
        } 
        
        // 🎯 2. RANDEVU
        else if (tip === 'Randevu') {
            const randevuQuery = `
                SELECT a.servis_no, a.tahsil_edilen_tutar, a.issue_text, a.created_at as islem_tarihi,
                COALESCE(c.name, f.firma_adi, 'Bilinmeyen Müşteri') as musteri_adi,
                COALESCE(c.phone, f.telefon, '') as telefon, COALESCE(c.address, f.adres, '') as adres, f.vergi_no
                FROM appointments a
                LEFT JOIN customers c ON a.customer_id = c.id
                LEFT JOIN firms f ON a.firm_id = f.id
                WHERE a.servis_no = $1
            `;
            const randevuResult = await db.query(randevuQuery, [servis_no]);

            if (randevuResult.rows.length > 0) {
                const data = randevuResult.rows[0];
                if (data.islem_tarihi) faturaVerisi.tarih = new Date(data.islem_tarihi).toLocaleDateString('tr-TR');
                
                const kasaQuery = `SELECT tutar FROM kasa_islemleri WHERE servis_no = $1 ORDER BY id DESC LIMIT 1`;
                const kasaResult = await db.query(kasaQuery, [servis_no]);
                let gercekKasaTutari = kasaResult.rows.length > 0 ? parseFloat(kasaResult.rows[0].tutar) : parseFloat(data.tahsil_edilen_tutar || 0);

                faturaVerisi.musteri = { adi: data.musteri_adi, telefon: data.telefon || "-", adres: data.adres || "Belirtilmemiş", vergiNo: data.vergi_no || "" };
                faturaVerisi.cihaz = { markaModel: "Randevu / Danışmanlık", seriNo: "-" };
                faturaVerisi.kalemler.push({ ad: data.issue_text || "Randevu Hizmeti", miktar: 1, fiyat: gercekKasaTutari, kdv: 20, toplam: gercekKasaTutari });
                faturaVerisi.toplamlar.genelToplam = gercekKasaTutari;
            } else { return res.json({ success: false, message: "Kayıt bulunamadı." }); }
        } 
        
        // 🎯 3. STOK SATIŞI (🚨 TEMİZLİK MOTORU BURADA ÇALIŞIYOR!)
        else if (tip === 'Stok') {
            const stokQuery = `
                SELECT k.aciklama, k.tutar, k.islem_tarihi, st.barkod, st.malzeme_adi
                FROM kasa_islemleri k 
                LEFT JOIN envanter st ON k.aciklama ILIKE '%' || st.malzeme_adi || '%'
                WHERE k.id = CAST($1 AS INT) AND k.kategori = 'Stok Satışı' LIMIT 1
            `;
            const stokResult = await db.query(stokQuery, [servis_no]);
            if (stokResult.rows.length > 0) {
                const data = stokResult.rows[0];
                if (data.islem_tarihi) faturaVerisi.tarih = new Date(data.islem_tarihi).toLocaleDateString('tr-TR');
                
                faturaVerisi.musteri = { adi: "Hızlı Satış Müşterisi", telefon: "-", adres: "-", vergiNo: "" };
                faturaVerisi.cihaz = { markaModel: data.malzeme_adi || "Stok Ürünü", seriNo: data.barkod || "Barkod Yok" };
                
                // --- 🧼 MÜDÜRÜN TEMİZLİK MOTORU ---
                let hamAciklama = data.aciklama || "Hızlı Satış";
                
                // 1. Adeti bul (Eğer metin içinde "Adet: 4" varsa 4'ü çeker, yoksa 1 yapar)
                let gercekMiktar = 1;
                const adetMatch = hamAciklama.match(/Adet:\s*(\d+)/i);
                if (adetMatch) { gercekMiktar = parseInt(adetMatch[1]); }
                
                // 2. Temiz İsim Çıkarma ("|" işaretinden öncesini alır. Alış: vs kısımları çöpe gider)
                let temizAd = hamAciklama.split('|')[0].trim();
                
                let genelToplam = parseFloat(data.tutar || 0);
                let birimFiyat = genelToplam / gercekMiktar; // Toplamı adete bölüp birim fiyatı bulur

                faturaVerisi.kalemler.push({ 
                    ad: temizAd, 
                    miktar: gercekMiktar, 
                    fiyat: birimFiyat, 
                    kdv: 20, 
                    toplam: genelToplam 
                });
                faturaVerisi.toplamlar.genelToplam = genelToplam;

            } else { return res.json({ success: false, message: "Kayıt bulunamadı." }); }
        }

        faturaVerisi.toplamlar.araToplam = faturaVerisi.toplamlar.genelToplam / 1.20; 
        faturaVerisi.toplamlar.kdvToplam = faturaVerisi.toplamlar.genelToplam - faturaVerisi.toplamlar.araToplam;
        return res.json({ success: true, faturaVerisi });

    } catch (err) {
        console.error("Fatura Detay Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});



// --- LİSTELEME MOTORU (ÇELİK VANA TAKILDI - KASA TARİHİ BAZ ALINIYOR) ---
router.get('/bekleyenler', async (req, res) => {
    const gun = req.query.gun || 1; 
    const gunFarki = Math.max(0, parseInt(gun) - 1); 
    try {
        const query = `
            SELECT s.servis_no as id, COALESCE(c.name, f.firma_adi, 'Bilinmeyen Müşteri') as musteri_adi, 'Tamir' as islem_tipi, COALESCE(d.brand, '') || ' ' || COALESCE(d.model, '') as cihaz, 
            COALESCE((SELECT tutar FROM kasa_islemleri WHERE servis_no = s.servis_no ORDER BY id DESC LIMIT 1), s.offer_price) as tutar, 
            s.updated_at as tarih
            FROM services s LEFT JOIN customers c ON s.customer_id = c.id LEFT JOIN firms f ON s.firm_id = f.id LEFT JOIN devices d ON s.device_id = d.id
            WHERE (s.status ILIKE 'Teslim Edildi' OR s.status ILIKE 'Bitti') AND DATE(s.updated_at) >= CURRENT_DATE - $1::int AND DATE(s.updated_at) >= '2020-08-01'
            UNION ALL
            -- 🚨 MÜDÜR: ÇELİK VANA BURADA! Randevu tablosunda olmayan sütunu aramak yerine, paranın KASAYA girdiği tarihi çekiyoruz!
            SELECT a.servis_no as id, COALESCE(c.name, f.firma_adi, 'Bilinmeyen Müşteri') as musteri_adi, 'Randevu' as islem_tipi, COALESCE(a.issue_text, 'Randevu İşlemi') as cihaz, 
            COALESCE((SELECT tutar FROM kasa_islemleri WHERE servis_no = a.servis_no ORDER BY id DESC LIMIT 1), a.tahsil_edilen_tutar) as tutar, 
            COALESCE((SELECT islem_tarihi FROM kasa_islemleri WHERE servis_no = a.servis_no ORDER BY id DESC LIMIT 1), a.created_at) as tarih
            FROM appointments a LEFT JOIN customers c ON a.customer_id = c.id LEFT JOIN firms f ON a.firm_id = f.id
            WHERE (a.status ILIKE 'Teslim Edildi' OR a.status ILIKE 'Bitti') 
            AND DATE(COALESCE((SELECT islem_tarihi FROM kasa_islemleri WHERE servis_no = a.servis_no ORDER BY id DESC LIMIT 1), a.created_at)) >= CURRENT_DATE - $1::int 
            AND DATE(COALESCE((SELECT islem_tarihi FROM kasa_islemleri WHERE servis_no = a.servis_no ORDER BY id DESC LIMIT 1), a.created_at)) >= '2020-08-01'
            UNION ALL
            SELECT CAST(k.id AS TEXT) as id, 'Hızlı Satış' as musteri_adi, 'Stok' as islem_tipi, COALESCE(k.aciklama, 'Stok Satışı') as cihaz, k.tutar as tutar, k.islem_tarihi as tarih
            FROM kasa_islemleri k 
            WHERE k.kategori = 'Stok Satışı' AND DATE(k.islem_tarihi) >= CURRENT_DATE - $1::int AND DATE(k.islem_tarihi) >= '2020-08-01'
            ORDER BY tarih DESC
        `;
        const result = await db.query(query, [gunFarki]);
        res.json({ success: true, data: result.rows });
    } catch (err) { res.status(500).json({ success: false, error: err.message }); }
});







/*


// --- LİSTELEME MOTORU (HAYALET KAYITLARDAN ARINDIRILDI) ---
router.get('/bekleyenler', async (req, res) => {
    const gun = req.query.gun || 1; 
    const gunFarki = Math.max(0, parseInt(gun) - 1); 
    try {
        const query = `
            SELECT s.servis_no as id, COALESCE(c.name, f.firma_adi, 'Bilinmeyen Müşteri') as musteri_adi, 'Tamir' as islem_tipi, COALESCE(d.brand, '') || ' ' || COALESCE(d.model, '') as cihaz, 
            COALESCE((SELECT tutar FROM kasa_islemleri WHERE servis_no = s.servis_no ORDER BY id DESC LIMIT 1), s.offer_price) as tutar, 
            s.updated_at as tarih
            FROM services s LEFT JOIN customers c ON s.customer_id = c.id LEFT JOIN firms f ON s.firm_id = f.id LEFT JOIN devices d ON s.device_id = d.id
            WHERE (s.status ILIKE 'Teslim Edildi' OR s.status ILIKE 'Bitti') AND DATE(s.updated_at) >= CURRENT_DATE - $1::int AND DATE(s.updated_at) >= '2020-08-01'
            UNION ALL
            SELECT a.servis_no as id, COALESCE(c.name, f.firma_adi, 'Bilinmeyen Müşteri') as musteri_adi, 'Randevu' as islem_tipi, COALESCE(a.issue_text, 'Randevu İşlemi') as cihaz, 
            COALESCE((SELECT tutar FROM kasa_islemleri WHERE servis_no = a.servis_no ORDER BY id DESC LIMIT 1), a.tahsil_edilen_tutar) as tutar, 
            a.created_at as tarih
            FROM appointments a LEFT JOIN customers c ON a.customer_id = c.id LEFT JOIN firms f ON a.firm_id = f.id
            WHERE (a.status ILIKE 'Teslim Edildi' OR a.status ILIKE 'Bitti') AND DATE(a.created_at) >= CURRENT_DATE - $1::int AND DATE(a.created_at) >= '2020-08-01'
            UNION ALL
            -- 🚨 MÜDÜR: İŞTE NEŞTERİ VURDUĞUMUZ YER BURASI! (EN ALT SATIR)
            -- Envanter JOIN'ini iptal ettik, direkt Kasa'nın tertemiz açıklamasını çektik.
            SELECT CAST(k.id AS TEXT) as id, 'Hızlı Satış' as musteri_adi, 'Stok' as islem_tipi, COALESCE(k.aciklama, 'Stok Satışı') as cihaz, k.tutar as tutar, k.islem_tarihi as tarih
            FROM kasa_islemleri k 
            WHERE k.kategori = 'Stok Satışı' AND DATE(k.islem_tarihi) >= CURRENT_DATE - $1::int AND DATE(k.islem_tarihi) >= '2020-08-01'
            ORDER BY tarih DESC
        `;
        const result = await db.query(query, [gunFarki]);
        res.json({ success: true, data: result.rows });
    } catch (err) { res.status(500).json({ success: false, error: err.message }); }
});








// --- LİSTELEME MOTORU ---
router.get('/bekleyenler', async (req, res) => {
    const gun = req.query.gun || 1; 
    const gunFarki = Math.max(0, parseInt(gun) - 1); 
    try {
        const query = `
            SELECT s.servis_no as id, COALESCE(c.name, f.firma_adi, 'Bilinmeyen Müşteri') as musteri_adi, 'Tamir' as islem_tipi, COALESCE(d.brand, '') || ' ' || COALESCE(d.model, '') as cihaz, 
            COALESCE((SELECT tutar FROM kasa_islemleri WHERE servis_no = s.servis_no ORDER BY id DESC LIMIT 1), s.offer_price) as tutar, 
            s.updated_at as tarih
            FROM services s LEFT JOIN customers c ON s.customer_id = c.id LEFT JOIN firms f ON s.firm_id = f.id LEFT JOIN devices d ON s.device_id = d.id
            WHERE (s.status ILIKE 'Teslim Edildi' OR s.status ILIKE 'Bitti') AND DATE(s.updated_at) >= CURRENT_DATE - $1::int AND DATE(s.updated_at) >= '2020-08-01'
            UNION ALL
            SELECT a.servis_no as id, COALESCE(c.name, f.firma_adi, 'Bilinmeyen Müşteri') as musteri_adi, 'Randevu' as islem_tipi, COALESCE(a.issue_text, 'Randevu İşlemi') as cihaz, 
            COALESCE((SELECT tutar FROM kasa_islemleri WHERE servis_no = a.servis_no ORDER BY id DESC LIMIT 1), a.tahsil_edilen_tutar) as tutar, 
            a.created_at as tarih
            FROM appointments a LEFT JOIN customers c ON a.customer_id = c.id LEFT JOIN firms f ON a.firm_id = f.id
            WHERE (a.status ILIKE 'Teslim Edildi' OR a.status ILIKE 'Bitti') AND DATE(a.created_at) >= CURRENT_DATE - $1::int AND DATE(a.created_at) >= '2020-08-01'
            UNION ALL
            SELECT CAST(k.id AS TEXT) as id, 'Hızlı Satış' as musteri_adi, 'Stok' as islem_tipi, 'Barkod: ' || COALESCE(st.barkod, 'Barkodsuz') || ' | ' || COALESCE(k.aciklama, 'Satış') as cihaz, k.tutar as tutar, k.islem_tarihi as tarih
            FROM kasa_islemleri k LEFT JOIN envanter st ON TRIM(k.aciklama) ILIKE '%' || TRIM(st.malzeme_adi) || '%'
            WHERE k.kategori = 'Stok Satışı' AND DATE(k.islem_tarihi) >= CURRENT_DATE - $1::int AND DATE(k.islem_tarihi) >= '2020-08-01'
            ORDER BY tarih DESC
        `;
        const result = await db.query(query, [gunFarki]);
        res.json({ success: true, data: result.rows });
    } catch (err) { res.status(500).json({ success: false, error: err.message }); }
});



*/






// Maliyet kontrol rutini
router.post('/maliyet-kontrol', async (req, res) => {
    const { servis_no, tahsil_edilecek_tutar } = req.body;
    if (!servis_no) return res.json({ success: true });

    try {
        const sQuery = await db.query('SELECT id FROM services WHERE servis_no = $1', [servis_no]);
        if (sQuery.rows.length === 0) return res.json({ success: true });
        
        const service_id = sQuery.rows[0].id;
        const pQuery = `
            SELECT SUM(mr.quantity * COALESCE(e.alis_fiyati, 0)) as toplam_maliyet
            FROM material_requests mr
            LEFT JOIN envanter e ON TRIM(mr.part_name) ILIKE '%' || TRIM(e.malzeme_adi) || '%'
            WHERE mr.service_id = $1
        `;
        const pResult = await db.query(pQuery, [service_id]);
        const maliyet = parseFloat(pResult.rows[0].toplam_maliyet || 0);
        const girilenTutar = parseFloat(tahsil_edilecek_tutar || 0);

        if (maliyet > girilenTutar) {
            return res.json({ 
                success: false, 
                message: `🚨 ZARARINA İŞLEM KİLİDİ!\n\nTahsil Etmeye Çalıştığınız: ${girilenTutar.toFixed(2)} ₺\nCihazdaki Parça Maliyeti: ${maliyet.toFixed(2)} ₺\n\nLütfen ustayı uyarın, tahsilat rakamı parça maliyetini kurtarmıyor! İşlem kasaya kaydedilemez.` 
            });
        }
        return res.json({ success: true });
    } catch (error) {
        console.error("Maliyet Kontrol Hatası:", error);
        return res.json({ success: true }); 
    }
});

module.exports = router;