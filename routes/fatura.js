const express = require('express');
const router = express.Router();
const db = require('../database'); 

router.get('/detay', async (req, res) => {
    const { servis_no } = req.query;

    if (!servis_no) {
        return res.status(400).json({ success: false, message: "Servis numarası gerekli!" });
    }

    try {
        let faturaVerisi = {
            belgeNo: servis_no,
            musteri: { adi: "", telefon: "", adres: "" },
            cihaz: { markaModel: "", seriNo: "" },
            kalemler: [],
            toplamlar: { araToplam: 0, kdvToplam: 0, genelToplam: 0 }
        };

        // 🎯 1. TAMİR
        const tamirQuery = `
            SELECT s.id as service_id, s.servis_no, s.offer_price as toplam_tutar, 
            COALESCE(c.name, f.firma_adi, 'Bilinmeyen Müşteri') as musteri_adi,
            COALESCE(c.phone, f.telefon, '') as telefon, 
            COALESCE(c.address, f.adres, '') as adres,
            d.brand, d.model, d.serial_no
            FROM services s
            LEFT JOIN customers c ON s.customer_id = c.id
            LEFT JOIN firms f ON s.firm_id = f.id
            LEFT JOIN devices d ON s.device_id = d.id
            WHERE s.servis_no = $1
        `;
        const tamirResult = await db.query(tamirQuery, [servis_no]);

        if (tamirResult.rows.length > 0) {
            const data = tamirResult.rows[0];
            faturaVerisi.musteri = { 
                adi: data.musteri_adi, 
                telefon: data.telefon || "-", 
                adres: data.adres || "Belirtilmemiş" 
            };
            faturaVerisi.cihaz = { markaModel: `${data.brand} ${data.model}`, seriNo: data.serial_no || "-" };
            
            const parcaQuery = `
                SELECT 
                    mr.part_name as ad, 
                    mr.quantity as miktar, 
                    CASE 
                        WHEN e.satis_fiyati > 0 THEN e.satis_fiyati 
                        ELSE COALESCE(e.alis_fiyati, 0) 
                    END as fiyat 
                FROM material_requests mr
                LEFT JOIN envanter e ON TRIM(mr.part_name) ILIKE '%' || TRIM(e.malzeme_adi) || '%'
                WHERE mr.service_id = $1
            `;
            const parcaResult = await db.query(parcaQuery, [data.service_id]);
            
            let anlasilanTutar = parseFloat(data.toplam_tutar || 0);

            if (parcaResult.rows.length > 0) {
                // 🚨 HATA BURADAYDI ÇÖZÜLDÜ: p.quantity yerine p.miktar yazıldı!
                let toplamParcaMaliyeti = parcaResult.rows.reduce((acc, p) => acc + (parseFloat(p.fiyat) * parseFloat(p.miktar)), 0);

                if (toplamParcaMaliyeti > anlasilanTutar) {
                    // 🚨 SENARYO A: Parçalar anlaşılan parayı aşıyor
                    faturaVerisi.kalemler = parcaResult.rows.map(p => ({
                        ad: `${p.ad} (Onarıma dahil edilmiştir)`,
                        miktar: p.miktar,
                        fiyat: 0,
                        kdv: 20,
                        toplam: 0
                    }));
                    // Tüm bakiye işçiliğe yansıtılır
                    faturaVerisi.kalemler.push({ 
                        ad: "İşçilik ve Genel Servis Bedeli", 
                        miktar: 1, 
                        fiyat: anlasilanTutar, 
                        kdv: 20, 
                        toplam: anlasilanTutar 
                    });
                } else {
                    // 🚨 SENARYO B: Normal Hesaplama
                    let parcaMaliyetiSum = 0;
                    faturaVerisi.kalemler = parcaResult.rows.map(p => {
                        let birimFiyat = parseFloat(p.fiyat);
                        let satirToplami = birimFiyat * parseFloat(p.miktar);
                        parcaMaliyetiSum += satirToplami;
                        return { ad: p.ad, miktar: p.miktar, fiyat: birimFiyat, kdv: 20, toplam: satirToplami };
                    });
                    let iscilikBedeli = Math.max(0, anlasilanTutar - parcaMaliyetiSum);
                    faturaVerisi.kalemler.push({ 
                        ad: "İşçilik ve Genel Servis Bedeli", 
                        miktar: 1, 
                        fiyat: iscilikBedeli, 
                        kdv: 20, 
                        toplam: iscilikBedeli 
                    });
                }
            } else {
                // Parça yoksa direkt işçilik
                faturaVerisi.kalemler.push({ ad: "İşçilik ve Genel Servis Bedeli", miktar: 1, fiyat: anlasilanTutar, kdv: 20, toplam: anlasilanTutar });
            }
            
            faturaVerisi.toplamlar.genelToplam = anlasilanTutar;

        } else {
            // 🎯 2. RANDEVU
            const randevuQuery = `
                SELECT a.servis_no, a.tahsil_edilen_tutar, a.issue_text,
                COALESCE(c.name, f.firma_adi, 'Bilinmeyen Müşteri') as musteri_adi,
                COALESCE(c.phone, f.telefon, '') as telefon, 
                COALESCE(c.address, f.adres, '') as adres
                FROM appointments a
                LEFT JOIN customers c ON a.customer_id = c.id
                LEFT JOIN firms f ON a.firm_id = f.id
                WHERE a.servis_no = $1
            `;
            const randevuResult = await db.query(randevuQuery, [servis_no]);

            if (randevuResult.rows.length > 0) {
                const data = randevuResult.rows[0];
                faturaVerisi.musteri = { 
                    adi: data.musteri_adi, 
                    telefon: data.telefon || "-", 
                    adres: data.adres || "Belirtilmemiş" 
                };
                faturaVerisi.cihaz = { markaModel: "Randevu / Danışmanlık", seriNo: "-" };
                faturaVerisi.kalemler.push({ ad: data.issue_text || "Randevu Hizmeti", miktar: 1, fiyat: parseFloat(data.tahsil_edilen_tutar || 0), kdv: 20, toplam: parseFloat(data.tahsil_edilen_tutar || 0) });
                faturaVerisi.toplamlar.genelToplam = parseFloat(data.tahsil_edilen_tutar || 0);
            } else {
                // 🎯 3. STOK SATIŞI
                if (!isNaN(servis_no)) {
                    const stokQuery = `
                        SELECT k.aciklama, k.tutar, st.barkod, st.malzeme_adi
                        FROM kasa_islemleri k 
                        LEFT JOIN envanter st ON k.aciklama ILIKE '%' || st.malzeme_adi || '%'
                        WHERE k.id = CAST($1 AS INT) AND k.kategori = 'Stok Satışı' LIMIT 1
                    `;
                    const stokResult = await db.query(stokQuery, [servis_no]);
                    if (stokResult.rows.length > 0) {
                        const data = stokResult.rows[0];
                        faturaVerisi.musteri = { adi: "Hızlı Satış Müşterisi", telefon: "-", adres: "-" };
                        faturaVerisi.cihaz = { markaModel: data.malzeme_adi || "Stok Ürünü", seriNo: data.barkod || "Barkod Yok" };
                        faturaVerisi.kalemler.push({ ad: data.aciklama || "Hızlı Satış", miktar: 1, fiyat: parseFloat(data.tutar || 0), kdv: 20, toplam: parseFloat(data.tutar || 0) });
                        faturaVerisi.toplamlar.genelToplam = parseFloat(data.tutar || 0);
                    } else { return res.json({ success: false, message: "Kayıt bulunamadı." }); }
                } else { return res.json({ success: false, message: "Kayıt bulunamadı." }); }
            }
        }

        faturaVerisi.toplamlar.araToplam = faturaVerisi.toplamlar.genelToplam / 1.20; 
        faturaVerisi.toplamlar.kdvToplam = faturaVerisi.toplamlar.genelToplam - faturaVerisi.toplamlar.araToplam;
        return res.json({ success: true, faturaVerisi });

    } catch (err) {
        console.error("Fatura Detay Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// --- LİSTELEME MOTORU ---
router.get('/bekleyenler', async (req, res) => {
    const gun = req.query.gun || 1; 
    const gunFarki = Math.max(0, parseInt(gun) - 1); 
    try {
        const query = `
            SELECT s.servis_no as id, COALESCE(c.name, f.firma_adi, 'Bilinmeyen Müşteri') as musteri_adi, 'Tamir' as islem_tipi, COALESCE(d.brand, '') || ' ' || COALESCE(d.model, '') as cihaz, s.offer_price as tutar, s.updated_at as tarih
            FROM services s LEFT JOIN customers c ON s.customer_id = c.id LEFT JOIN firms f ON s.firm_id = f.id LEFT JOIN devices d ON s.device_id = d.id
            WHERE (s.status ILIKE 'Hazır' OR s.status ILIKE 'Teslim Edildi' OR s.status ILIKE 'Bitti') AND DATE(s.updated_at) >= CURRENT_DATE - $1::int AND DATE(s.updated_at) >= '2020-08-01'
            UNION ALL
            SELECT a.servis_no as id, COALESCE(c.name, f.firma_adi, 'Bilinmeyen Müşteri') as musteri_adi, 'Randevu' as islem_tipi, COALESCE(a.issue_text, 'Randevu İşlemi') as cihaz, a.tahsil_edilen_tutar as tutar, a.created_at as tarih
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

module.exports = router;