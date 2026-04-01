const express = require('express');
const router = express.Router();
const db = require('../database'); 

// --- 1. TÜM DEPOYU GETİR ---
router.get('/all', async (req, res) => {
    try {
        const result = await db.query("SELECT * FROM envanter ORDER BY son_guncelleme DESC");
        res.json({ success: true, data: result.rows });
    } catch (err) {
        console.error("Depo listeleme hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});




// --- 2. STOK GİRİŞİ YAP VE KASADAN PARAYI DÜŞ (FİYAT RADARLI VE +1 HIZLI İŞLEM DESTEKLİ) ---
router.post('/add', async (req, res) => {
    // Müdür: 'fiyat_guncelle' şalterini req.body'den alıyoruz
    const { barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati, request_id, fiyat_guncelle } = req.body;
    
    // Eğer mobilden değer gelmezse varsayılan olarak fiyatı günceller (Güvenlik)
    const updatePriceFlag = fiyat_guncelle !== false; 

    try {
        await db.query('BEGIN'); 
        
        // 1. ZIRHLI ENVANTER KAYDI (7. Parametre = Fiyat Güncelleme Şalteri)
        const insertQuery = `
            INSERT INTO envanter (barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati)
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (barkod) 
            DO UPDATE SET 
                miktar = envanter.miktar + EXCLUDED.miktar,
                -- 🚨 ŞALTER BURADA: $7 True ise yeni fiyatı yaz, False ise eski fiyatı koru!
                alis_fiyati = CASE WHEN $7 = TRUE AND EXCLUDED.alis_fiyati > 0 THEN EXCLUDED.alis_fiyati ELSE envanter.alis_fiyati END,
                malzeme_adi = CASE WHEN EXCLUDED.malzeme_adi <> '' AND EXCLUDED.malzeme_adi IS NOT NULL THEN EXCLUDED.malzeme_adi ELSE envanter.malzeme_adi END,
                marka = CASE WHEN EXCLUDED.marka <> '' AND EXCLUDED.marka IS NOT NULL THEN EXCLUDED.marka ELSE envanter.marka END,
                uyumlu_cihaz = CASE WHEN EXCLUDED.uyumlu_cihaz <> '' AND EXCLUDED.uyumlu_cihaz IS NOT NULL THEN EXCLUDED.uyumlu_cihaz ELSE envanter.uyumlu_cihaz END,
                son_guncelleme = CURRENT_TIMESTAMP
            RETURNING *;
        `;
        
        const result = await db.query(insertQuery, [barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati, updatePriceFlag]);
        const guncelMalzeme = result.rows[0];

        // --- 💰 2. MALİYE BAKANLIĞI (HIZLI +1 DESTEKLİ KASA DÜŞÜŞÜ) 💰 ---
        const ekrandanGelenFiyat = parseFloat(alis_fiyati || 0);
        const kayitliFiyat = parseFloat(guncelMalzeme.alis_fiyati || 0);
        // Eğer formdan fiyat girilmişse onu baz al, girilmemişse (+1 okutmasıysa) veritabanındaki kayıtlı fiyatı al!
        const birimFiyat = ekrandanGelenFiyat > 0 ? ekrandanGelenFiyat : kayitliFiyat;

        const adet = parseInt(miktar || 1);
        const toplamMaliyet = birimFiyat * adet;

        if (toplamMaliyet > 0) {
            const malzemeIsmi = malzeme_adi || guncelMalzeme.malzeme_adi || 'Bilinmeyen Malzeme';
            let islemTuru = 'Genel Stok Alımı';
            
            if (request_id) islemTuru = 'Usta Siparişi Alımı';
            else if (!malzeme_adi) islemTuru = 'Hızlı İşlem Radarı (+1)';

            const kasaAciklama = `${islemTuru}: ${malzemeIsmi} | Adet: ${adet} | Birim: ${birimFiyat} ₺`;
            
            await db.query(
                `INSERT INTO kasa_islemleri (islem_yonu, kategori, tutar, aciklama, islem_yapan) 
                 VALUES ('ÇIKIŞ', 'Mal Alımı', $1, $2, 'Banko Stok Girişi')`,
                [toplamMaliyet, kasaAciklama]
            );
        }

        // --- 3. USTA TALEBİ KONTROLÜ (Listeden Düşürme) ---
        if (request_id) {
            await db.query("UPDATE material_requests SET stok_girisi_yapildi_mi = TRUE, status = 'Onay Bekliyor' WHERE id = $1", [request_id]);
            const logQuery = `
                INSERT INTO service_notes (service_id, note_text) 
                SELECT service_id, 'LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.' 
                FROM material_requests 
                WHERE id = $1
            `;
            await db.query(logQuery, [request_id]);
        }

        await db.query('COMMIT'); 
        res.json({ success: true, message: 'Stok eklendi ve kasadan düşüldü.', data: guncelMalzeme });
        
    } catch (err) {
        await db.query('ROLLBACK'); 
        console.error("Stok Giriş Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});







/*

// --- 2. STOK GİRİŞİ YAP VE KASADAN PARAYI DÜŞ (FİYAT RADARLI TAM ENTEGRE) ---
router.post('/add', async (req, res) => {
    // Müdür: 'fiyat_guncelle' şalterini req.body'den alıyoruz
    const { barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati, request_id, fiyat_guncelle } = req.body;
    
    // Eğer mobilden değer gelmezse varsayılan olarak fiyatı günceller (Güvenlik)
    const updatePriceFlag = fiyat_guncelle !== false; 

    try {
        await db.query('BEGIN'); 
        
        // 1. ZIRHLI ENVANTER KAYDI (7. Parametre = Fiyat Güncelleme Şalteri)
        const insertQuery = `
            INSERT INTO envanter (barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati)
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (barkod) 
            DO UPDATE SET 
                miktar = envanter.miktar + EXCLUDED.miktar,
                -- 🚨 ŞALTER BURADA: $7 True ise yeni fiyatı yaz, False ise eski fiyatı koru!
                alis_fiyati = CASE WHEN $7 = TRUE AND EXCLUDED.alis_fiyati > 0 THEN EXCLUDED.alis_fiyati ELSE envanter.alis_fiyati END,
                malzeme_adi = CASE WHEN EXCLUDED.malzeme_adi <> '' AND EXCLUDED.malzeme_adi IS NOT NULL THEN EXCLUDED.malzeme_adi ELSE envanter.malzeme_adi END,
                marka = CASE WHEN EXCLUDED.marka <> '' AND EXCLUDED.marka IS NOT NULL THEN EXCLUDED.marka ELSE envanter.marka END,
                uyumlu_cihaz = CASE WHEN EXCLUDED.uyumlu_cihaz <> '' AND EXCLUDED.uyumlu_cihaz IS NOT NULL THEN EXCLUDED.uyumlu_cihaz ELSE envanter.uyumlu_cihaz END,
                son_guncelleme = CURRENT_TIMESTAMP
            RETURNING *;
        `;
        
        const result = await db.query(insertQuery, [barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati, updatePriceFlag]);
        const guncelMalzeme = result.rows[0];


       
        
        // --- 💰 2. MALİYE BAKANLIĞI (Kasadan Parayı Düş) 💰 ---
        const birimFiyat = parseFloat(alis_fiyati || 0);
        const adet = parseInt(miktar || 1);
        const toplamMaliyet = birimFiyat * adet;

        if (toplamMaliyet > 0) {
            // Müdür: Banko bu malı ustanın siparişi üzerine mi aldı, yoksa öylesine mi? Açıklamaya yazıyoruz.
            const islemTuru = request_id ? 'Usta Siparişi Alımı' : 'Genel Stok Alımı';
            const kasaAciklama = `${islemTuru}: ${malzeme_adi} | Adet: ${adet} | Birim: ${birimFiyat} ₺`;
            
            await db.query(
                `INSERT INTO kasa_islemleri (islem_yonu, kategori, tutar, aciklama, islem_yapan) 
                 VALUES ('ÇIKIŞ', 'Mal Alımı', $1, $2, 'Banko Stok Girişi')`,
                [toplamMaliyet, kasaAciklama]
            );
        }

        // --- 3. USTA TALEBİ KONTROLÜ (Listeden Düşürme) ---
        if (request_id) {
            await db.query("UPDATE material_requests SET stok_girisi_yapildi_mi = TRUE, status = 'Onay Bekliyor' WHERE id = $1", [request_id]);
            const logQuery = `
                INSERT INTO service_notes (service_id, note_text) 
                SELECT service_id, 'LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.' 
                FROM material_requests 
                WHERE id = $1
            `;
            await db.query(logQuery, [request_id]);
        }

        await db.query('COMMIT'); 
        res.json({ success: true, message: 'Stok eklendi ve kasadan düşüldü.', data: guncelMalzeme });
        
    } catch (err) {
        await db.query('ROLLBACK'); 
        console.error("Stok Giriş Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});


*/





/*
// --- 2. STOK GİRİŞİ YAP (ZIRHLI VE KASAYA BAĞLI VERSİYON) ---
router.post('/add', async (req, res) => {
    const { barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati, request_id } = req.body;
    try {
        await db.query('BEGIN');
        
        // 1. ZIRHLI EKLEME / GÜNCELLEME İŞLEMİ
        const insertQuery = `
            INSERT INTO envanter (barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati)
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (barkod) 
            DO UPDATE SET 
                miktar = envanter.miktar + EXCLUDED.miktar,
                alis_fiyati = CASE WHEN EXCLUDED.alis_fiyati > 0 THEN EXCLUDED.alis_fiyati ELSE envanter.alis_fiyati END,
                malzeme_adi = CASE WHEN EXCLUDED.malzeme_adi <> '' AND EXCLUDED.malzeme_adi IS NOT NULL THEN EXCLUDED.malzeme_adi ELSE envanter.malzeme_adi END,
                marka = CASE WHEN EXCLUDED.marka <> '' AND EXCLUDED.marka IS NOT NULL THEN EXCLUDED.marka ELSE envanter.marka END,
                uyumlu_cihaz = CASE WHEN EXCLUDED.uyumlu_cihaz <> '' AND EXCLUDED.uyumlu_cihaz IS NOT NULL THEN EXCLUDED.uyumlu_cihaz ELSE envanter.uyumlu_cihaz END,
                son_guncelleme = CURRENT_TIMESTAMP
            RETURNING *;
        `;
        const result = await db.query(insertQuery, [barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati]);
        const guncelMalzeme = result.rows[0];

        // --- 🚨 MÜDÜRÜN MUSLUĞU: SADECE HIZLI İŞLEMLERDE KASADAN PARA ÇIKAR ---
        // Eğer malzeme_adi boş gelmişse (Bu kesinlikle Hızlı İşlem Radarıdır!)
        if (!malzeme_adi || malzeme_adi.trim() === '') {
            const cikisTutari = parseFloat(guncelMalzeme.alis_fiyati) * parseInt(miktar);
            
            // Eğer ürünün gerçekten bir alış fiyatı varsa kasadan düş
            if (cikisTutari > 0) {
                const kasaAciklama = `Hızlı Stok Alımı: ${guncelMalzeme.malzeme_adi} | Adet: ${miktar} | Birim: ${guncelMalzeme.alis_fiyati} ₺`;
                
                await db.query(
                    `INSERT INTO kasa_islemleri (islem_yonu, kategori, tutar, aciklama, islem_yapan) 
                     VALUES ('ÇIKIŞ', 'Hızlı Barkod Alımı', $1, $2, 'Barkod İşlem')`,
                    [cikisTutari, kasaAciklama]
                );
            }
        }

        
        // 3. EĞER TALEP (REQUEST) ÜZERİNDEN GELDİYSE ONAY SÜRECİNİ İŞLET
        if (request_id) {
            await db.query("UPDATE material_requests SET stok_girisi_yapildi_mi = TRUE, status = 'Onay Bekliyor' WHERE id = $1", [request_id]);
            const logQuery = `
                INSERT INTO service_notes (service_id, note_text) 
                SELECT service_id, 'LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.' 
                FROM material_requests 
                WHERE id = $1
            `;
            await db.query(logQuery, [request_id]);
        }

        await db.query('COMMIT');
        res.json({ success: true, message: 'Stok eklendi ve işlem tamamlandı.', data: guncelMalzeme });
    } catch (err) {
        await db.query('ROLLBACK');
        console.error("Stok Giriş Hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});
*/






/*
// --- 2. STOK GİRİŞİ YAP (ZIRHLI VERSİYON) ---
router.post('/add', async (req, res) => {
    const { barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati, request_id } = req.body;
    try {
        await db.query('BEGIN');
        
        // MÜDÜR DİKKAT: CASE WHEN ile fiyatı ve isimleri korumaya aldık!
        const insertQuery = `
            INSERT INTO envanter (barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati)
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (barkod) 
            DO UPDATE SET 
                miktar = envanter.miktar + EXCLUDED.miktar,
                
                -- Eğer gelen fiyat 0'dan büyükse yenisini yaz, yoksa ESKİ fiyatı koru
                alis_fiyati = CASE WHEN EXCLUDED.alis_fiyati > 0 THEN EXCLUDED.alis_fiyati ELSE envanter.alis_fiyati END,
                
                -- Eğer isim boş gönderilmişse (Hızlı işlemdeki gibi), ESKİ ismi koru
                malzeme_adi = CASE WHEN EXCLUDED.malzeme_adi <> '' AND EXCLUDED.malzeme_adi IS NOT NULL THEN EXCLUDED.malzeme_adi ELSE envanter.malzeme_adi END,
                marka = CASE WHEN EXCLUDED.marka <> '' AND EXCLUDED.marka IS NOT NULL THEN EXCLUDED.marka ELSE envanter.marka END,
                uyumlu_cihaz = CASE WHEN EXCLUDED.uyumlu_cihaz <> '' AND EXCLUDED.uyumlu_cihaz IS NOT NULL THEN EXCLUDED.uyumlu_cihaz ELSE envanter.uyumlu_cihaz END,
                
                son_guncelleme = CURRENT_TIMESTAMP
            RETURNING *;
        `;
        const result = await db.query(insertQuery, [barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati]);

        if (request_id) {
            await db.query("UPDATE material_requests SET stok_girisi_yapildi_mi = TRUE, status = 'Onay Bekliyor' WHERE id = $1", [request_id]);
            const logQuery = `
                INSERT INTO service_notes (service_id, note_text) 
                SELECT service_id, 'LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.' 
                FROM material_requests 
                WHERE id = $1
            `;
            await db.query(logQuery, [request_id]);
        }
        await db.query('COMMIT');
        res.json({ success: true, message: 'Stok başarıyla eklendi.', data: result.rows[0] });
    } catch (err) {
        await db.query('ROLLBACK');
        res.status(500).json({ success: false, error: err.message });
    }
});







// --- 2. STOK GİRİŞİ YAP ---
router.post('/add', async (req, res) => {
    const { barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati, request_id } = req.body;
    try {
        await db.query('BEGIN');
        const insertQuery = `
            INSERT INTO envanter (barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati)
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (barkod) 
            DO UPDATE SET 
                miktar = envanter.miktar + EXCLUDED.miktar,
                alis_fiyati = EXCLUDED.alis_fiyati,
                son_guncelleme = CURRENT_TIMESTAMP
            RETURNING *;
        `;
        const result = await db.query(insertQuery, [barkod, malzeme_adi, uyumlu_cihaz, marka, miktar, alis_fiyati]);

        if (request_id) {
            await db.query("UPDATE material_requests SET stok_girisi_yapildi_mi = TRUE, status = 'Onay Bekliyor' WHERE id = $1", [request_id]);
            const logQuery = `
                INSERT INTO service_notes (service_id, note_text) 
                SELECT service_id, 'LOG: Parça için stok girişi yapıldı, Banko onayı bekleniyor.' 
                FROM material_requests 
                WHERE id = $1
            `;
            await db.query(logQuery, [request_id]);
        }
        await db.query('COMMIT');
        res.json({ success: true, message: 'Stok başarıyla eklendi.', data: result.rows[0] });
    } catch (err) {
        await db.query('ROLLBACK');
        res.status(500).json({ success: false, error: err.message });
    }
});

*/




// --- 🚨 MÜDÜR: 'sell' ROUTER'ININ YENİ VE KESİN HALİ ---
router.post('/sell', async (req, res) => {
    // 1. 🚨 BÜYÜK DÜZELTME: 'satis_fiyati' değerini mobilden teslim alıyoruz!
    const { id, barkod, cikan_adet, manual_discount, satis_fiyati } = req.body;

    try {
        await db.query('BEGIN');

        // 1. Ürünü Veritabanından Bul
        const invRes = await db.query("SELECT * FROM envanter WHERE id = $1 OR barkod = $2", [id, barkod]);
        if (invRes.rows.length === 0) throw new Error("Malzeme yok!");
        
        // 🚨 KRİTİK SATIR BURASI: 'mal' değişkeni burada doğuyor!
        const mal = invRes.rows[0];

        // 🚨 MÜDÜRÜN KANUNU: EKSİ STOK YASAK! (Bunu yeni ekledik)
        if (parseInt(mal.miktar) < parseInt(cikan_adet)) {
            throw new Error(`Yetersiz stok! Depoda sadece ${mal.miktar} adet var.`);
        }



        let nihaiBirimSatis = 0;

        // 2. 🚨 MÜDÜRÜN KANUNU (VİTRİN NEYSE KASA ODUR):
        // Eğer mobilden o jilet gibi hesaplanmış fiyat geldiyse, arka planda hiç formüle girme!
        if (satis_fiyati !== undefined && satis_fiyati !== null) {
            nihaiBirimSatis = Math.round(parseFloat(satis_fiyati));
        } else {
            // Eğer eski bir ekrandan veya başka bir yerden fiyat gelmeden tetiklenirse B Planı çalışsın:
            const settingsRes = await db.query("SELECT * FROM shop_settings");
            const getSetting = (key, defaultValue) => parseFloat(settingsRes.rows.find(r => r.key_name === key)?.value_text || defaultValue);

            const birimAlis = parseFloat(mal.alis_fiyati || 0);
            const varsayilanKarOrani = getSetting('profit_margin', 25);
            const aktifKdvOrani = getSetting('default_tax_rate', 20);
            const indirimYuzdesi = parseFloat(manual_discount || 0);

            if (birimAlis > 0) {
                // 🚨 ESNAF MATEMATİĞİ BURADA DA DEVREDE
                const hamKarMiktari = birimAlis * (varsayilanKarOrani / 100);
                const netKarMiktari = hamKarMiktari * (1 - (indirimYuzdesi / 100));
                const matrah = birimAlis + netKarMiktari;
                nihaiBirimSatis = Math.round(matrah * (1 + (aktifKdvOrani / 100)));
            } else {


                /*

            if (birimAlis > 0) {
                const netKarOrani = varsayilanKarOrani - indirimYuzdesi;
                const matrah = birimAlis * (1 + (netKarOrani / 100));
                nihaiBirimSatis = Math.round(matrah * (1 + (aktifKdvOrani / 100)));
            } else {

                */

                const eskiSatis = parseFloat(mal.satis_fiyati || 0);
                nihaiBirimSatis = Math.round(eskiSatis * (1 - (indirimYuzdesi / 100)));
            }
        }

        const toplamTahsilat = nihaiBirimSatis * parseInt(cikan_adet);

        // 3. Stok Düş (Miktar NULL korumalı)

        await db.query("UPDATE envanter SET miktar = COALESCE(miktar, 0) - $1, son_guncelleme = CURRENT_TIMESTAMP WHERE id = $2", [cikan_adet, mal.id]);
       // await db.query("UPDATE envanter SET miktar = COALESCE(miktar, 0) - $1 WHERE id = $2", [cikan_adet, mal.id]);
        
        // 4. 💰 KASAYA GİRİŞ YAP (Tam Entegrasyon)
        const indirimNotu = parseFloat(manual_discount || 0) > 0 ? ` (%${manual_discount} İskonto)` : "";
        const kasaAciklama = `Stok Satışı: ${mal.malzeme_adi}${indirimNotu} | Adet: ${cikan_adet} | Birim: ${nihaiBirimSatis} ₺`;
        
        await db.query(`INSERT INTO kasa_islemleri (islem_yonu, kategori, tutar, aciklama, islem_yapan) 
                        VALUES ('GİRİŞ', 'Stok Satışı', $1, $2, 'Barkod Satış')`, 
                        [toplamTahsilat, kasaAciklama]);

        await db.query('COMMIT');
        res.json({ success: true, message: `Tahsilat: ${toplamTahsilat} TL Kasaya Yazıldı.` });

    } catch (err) {
        await db.query('ROLLBACK');
        res.status(500).json({ success: false, error: err.message });
    }
});




//  burası stok içideki satışın kasa ya yollaması ve satış fiyatı düzeltmesi için pasif oldu 
/*
router.post('/sell', async (req, res) => {
    const { id, barkod, cikan_adet, manual_discount } = req.body;

    try {
        await db.query('BEGIN');

        const invRes = await db.query("SELECT * FROM envanter WHERE id = $1 OR barkod = $2", [id, barkod]);
        if (invRes.rows.length === 0) throw new Error("Malzeme yok!");
        const mal = invRes.rows[0];

        const settingsRes = await db.query("SELECT * FROM shop_settings");
        const getSetting = (key) => parseFloat(settingsRes.rows.find(r => r.key_name === key)?.value_text || "0");

        // 1. Temel Değerler
        const birimAlis = parseFloat(mal.alis_fiyati || 0);
        const defaultKar = parseFloat(getSetting('profit_margin') || 20);
        const aktifKdv = parseFloat(getSetting('default_tax_rate') || 20);
        const indirimOrani = parseFloat(manual_discount || 0);

        let birimSatis = 0;
        let indirimNotu = indirimOrani > 0 ? ` (%${indirimOrani} İskonto)` : "";

        // --- 🚨 MÜDÜR: İŞTE O GERÇEK HESAP BURADA ---
        if (birimAlis > 0) {
            // İndirim SADECE kâr oranından düşer
            const netKarOrani = defaultKar - indirimOrani; 
            
            // Yeni Matrah = Alış + (Alış * Net Kâr)
            const matrah = birimAlis * (1 + (netKarOrani / 100));
            // KDV'yi de bu yeni matrah üstünden bin
            const kdvTutari = matrah * (aktifKdv / 100);
            birimSatis = matrah + kdvTutari;
        } else {
            // Eğer alış fiyatı hala sıfırsa, mecburen elle girilen fiyattan yüzde düşer (B planı)
            const eskiSatis = parseFloat(mal.satis_fiyati || 0);
            birimSatis = eskiSatis * (1 - (indirimOrani / 100));
        }

        const toplamTahsilat = birimSatis * parseInt(cikan_adet);

        // Stok düş ve Kasa işlemleri...
        await db.query("UPDATE envanter SET miktar = miktar - $1 WHERE id = $2", [cikan_adet, mal.id]);
        
        const kasaAciklama = `Stok Satışı: ${mal.malzeme_adi}${indirimNotu} | Alış: ${birimAlis} | Satış: ${birimSatis.toFixed(2)}`;
        await db.query(`INSERT INTO kasa_islemleri (islem_yonu, kategori, tutar, aciklama, islem_yapan) 
                        VALUES ('GİRİŞ', 'Stok Satışı', $1, $2, 'Barkod Satış')`, 
                        [toplamTahsilat, kasaAciklama]);

        await db.query('COMMIT');
        res.json({ success: true, message: `Tahsilat: ${toplamTahsilat.toFixed(2)} TL` });

    } catch (err) {
        await db.query('ROLLBACK');
        res.status(500).json({ success: false, error: err.message });
    }
});
*/


// --- 4. SİLME VE GÜNCELLEME ---
router.delete('/delete/:id', async (req, res) => {
    try {
        await db.query("DELETE FROM envanter WHERE id = $1", [req.params.id]);
        res.json({ success: true, message: 'Stok kartı silindi.' });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

router.put('/update/:id', async (req, res) => {
    const { malzeme_adi, marka, miktar, alis_fiyati, barkod, uyumlu_cihaz } = req.body;
    try {
        await db.query(
            "UPDATE envanter SET malzeme_adi=$1, marka=$2, miktar=$3, alis_fiyati=$4, barkod=$5, uyumlu_cihaz=$6, son_guncelleme=CURRENT_TIMESTAMP WHERE id=$7",
            [malzeme_adi, marka, miktar, alis_fiyati, barkod, uyumlu_cihaz, req.params.id]
        );
        res.json({ success: true, message: 'Güncellendi.' });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

// --- 5. AKILLI RADAR ---
router.get('/search', async (req, res) => {
    const { malzeme_adi, barkod } = req.query;
    try {
        let query = "";
        let values = [];
        if (barkod) {
            query = "SELECT * FROM envanter WHERE barkod = $1 LIMIT 1";
            values = [barkod];
        } else if (malzeme_adi) {
            query = "SELECT * FROM envanter WHERE malzeme_adi ILIKE $1 LIMIT 1";
            values = [`%${malzeme_adi}%`];
        }
        const result = await db.query(query, values);
        res.json({ success: true, data: result.rows[0], found: result.rows.length > 0 });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});



// --- MÜDÜR: ÜRÜN ÖZELİNDE FİYAT GEÇMİŞİNİ GETİR ---
router.get('/history/:id', async (req, res) => {
    const { id } = req.params;
    try {
        const result = await db.query(
            "SELECT * FROM price_history WHERE inventory_id = $1 ORDER BY degisim_tarihi DESC LIMIT 20",
            [id]
        );
        
        // Eğer veri varsa gönder, yoksa boş dizi gönder
        res.json({ 
            success: true, 
            data: result.rows 
        });
    } catch (err) {
        console.error("Geçmiş çekme hatası:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});



module.exports = router;