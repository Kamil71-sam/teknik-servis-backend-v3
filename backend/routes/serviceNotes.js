const express = require("express");
const router = express.Router();
const db = require("../database");

// servis notu ekleme
router.post("/", async (req, res) => {
  const { service_id, note_text } = req.body;

  try {
    const result = await db.query(
      "INSERT INTO service_notes (service_id, note_text) VALUES ($1,$2) RETURNING id",
      [service_id, note_text]
    );

    res.json({
      message: "Servis notu eklendi",
      id: result.rows[0].id
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// servis notlarını listeleme
router.get("/", async (req, res) => {
  try {
    const result = await db.query(
      "SELECT * FROM service_notes ORDER BY id ASC"
    );

    res.json(result.rows);

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;