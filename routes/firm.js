
const express = require('express');
const router = express.Router();
const pool = require('../database'); // 🔥 İŞTE BU KADAR! DİREKT ANA ŞALTERE BAĞLADIK!



// --- YENİ FİRMA KAYIT (POST) ---
router.post('/add', async (req, res) => {
  const { firma_adi, yetkili_ad_soyad, telefon, faks, vergi_no, eposta, adres } = req.body;

  if (!firma_adi) {
    return res.status(400).json({ success: false, error: "Firma adı / Ünvanı zorunludur müdürüm!" });
  }

  try {
    const query = `
      INSERT INTO firms (firma_adi, yetkili_ad_soyad, telefon, faks, vergi_no, eposta, adres)
      VALUES ($1, $2, $3, $4, $5, $6, $7) 
      RETURNING *`;
    
    // Uygulamadan faks gelmezse undefined olup çökmesin diye faks || null yaptık
    const values = [firma_adi, yetkili_ad_soyad, telefon, faks || null, vergi_no, eposta, adres];
    const result = await pool.query(query, values);

    res.status(201).json({ 
      success: true, 
      message: "Firma kaydı dükkan defterine mühürlendi!", 
      data: result.rows[0] 
    });
  } catch (err) {
    console.error("Firma kayıt hatası:", err.message);
    res.status(500).json({ success: false, error: "Sunucu hatası: " + err.message });
  }
});

// --- TÜM FİRMALARI ÇEKME (GET) ---
router.get('/all', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM firms ORDER BY firma_adi ASC');
    res.json(result.rows);
  } catch (err) {
    console.error("Firma çekme hatası:", err.message);
    res.status(500).json({ error: "Veriler dükkandan gelmiyor: " + err.message });
  }
});


// --- MÜDÜR: AKILLI VE KÖKTEN SİLME (DELETE) ---
router.delete("/:id", async (req, res) => {
  const { id } = req.params;
  const { force } = req.query; // Mobilden "force=true" şifresi gelirse acımadan sileceğiz.

  try {
    // 1. KONTROL AŞAMASI: Bu firmaya ait içeride servis kaydı var mı?
    const checkQuery = `
      SELECT s.servis_no 
      FROM services s
      JOIN devices d ON s.device_id = d.id
      WHERE d.firm_id = $1
    `;
    const checkResult = await pool.query(checkQuery, [id]);

    // 2. UYARI AŞAMASI: Kayıt varsa ve mobilden "acımadan sil (force)" emri HENÜZ gelmediyse:
    if (checkResult.rowCount > 0 && force !== 'true') {
      const servisNumaralari = checkResult.rows.map(row => row.servis_no).join(', ');
      
      return res.json({ 
        uyariVar: true, 
        message: `Bu firmaya ait [ ${servisNumaralari} ] numaralı iş kayıtları var.\n\nYine de hem firmayı hem de bu işleri SONSUZA KADAR silmek istiyor musunuz?` 
      });
    }

    // MÜDÜR NOTU: İş kaydı yok ama cihazı varsa diye ekstra kontrol (Yine uyaralım)
    const checkDeviceOnly = await pool.query("SELECT id FROM devices WHERE firm_id = $1", [id]);
    if (checkDeviceOnly.rowCount > 0 && checkResult.rowCount === 0 && force !== 'true') {
        return res.json({
            uyariVar: true,
            message: `Bu firmanın üzerine kayıtlı cihaz(lar) var ama hiç işlem görmemiş.\n\nYine de firmayı ve cihazlarını SONSUZA KADAR silmek istiyor musunuz?`
        });
    }

    // 3. İNFAZ AŞAMASI: Kayıt yoksa veya mobilden "force=true" emri geldiyse acımıyoruz!
    
    await pool.query('BEGIN'); // Veritabanı işlemini başlatıyoruz

    // a) Varsa bu firmaya ait servis notlarını (service_notes) uçur
    await pool.query(`DELETE FROM service_notes WHERE service_id IN (SELECT s.id FROM services s JOIN devices d ON s.device_id = d.id WHERE d.firm_id = $1)`, [id]);
    
    // b) Servis (iş) kayıtlarını uçur
    await pool.query(`DELETE FROM services WHERE device_id IN (SELECT id FROM devices WHERE firm_id = $1)`, [id]);
    
    // c) Cihazları uçur
    await pool.query(`DELETE FROM devices WHERE firm_id = $1`, [id]);
    
    // d) En son firmanın kendisini yeryüzünden sil
    const deleteResult = await pool.query(`DELETE FROM firms WHERE id = $1`, [id]);

    await pool.query('COMMIT'); // İşlemi onayla ve fişi çek

    if (deleteResult.rowCount > 0) {
      res.json({ success: true, uyariVar: false, message: "Firma ve tüm geçmişi kökten silindi." });
    } else {
      res.status(404).json({ success: false, message: "Silinmek istenen firma kaydı bulunamadı." });
    }

  } catch (err) {
    await pool.query('ROLLBACK'); // Hata olursa hiçbir şeyi silme, sistemi geri al
    console.error("Firma silme hatası:", err.message);
    res.status(500).json({ success: false, error: "Silme sırasında hata oluştu: " + err.message });
  }
});

// --- 2. FİRMA GÜNCELLEME (Düzeltme) ---
router.put("/:id", async (req, res) => {
  const { id } = req.params;
  const { firma_adi, yetkili_ad_soyad, telefon, faks, vergi_no, eposta, adres } = req.body;

  if (!firma_adi) {
    return res.status(400).json({ success: false, error: "Firma adı boş bırakılamaz müdürüm!" });
  }

  try {
    const query = `
      UPDATE firms 
      SET firma_adi = $1, yetkili_ad_soyad = $2, telefon = $3, faks = $4, vergi_no = $5, eposta = $6, adres = $7 
      WHERE id = $8 RETURNING *`;
    
    const values = [firma_adi, yetkili_ad_soyad, telefon, faks || null, vergi_no, eposta, adres, id];
    const result = await pool.query(query, values);

    if (result.rowCount > 0) {
      res.json({ success: true, message: "Firma bilgileri jilet gibi güncellendi!" });
    } else {
      res.status(404).json({ success: false, message: "Güncellenecek firma bulunamadı." });
    }

  } catch (err) {
    console.error("Firma güncelleme hatası:", err.message);
    res.status(500).json({ success: false, error: "Güncelleme sırasında hata oluştu: " + err.message });
  }
});

module.exports = router;