const express = require("express");
const router = express.Router();
const db = require("../database");


// yeni bilgi girişi
router.post("/", async (req, res) => {
  const { name, phone, fax, email, address } = req.body;

  try {
    const result = await db.query(
      "INSERT INTO customers (name, phone, fax, email, address) VALUES ($1, $2, $3, $4, $5) RETURNING id",
      [name, phone, fax, email, address]
    );

    res.json({
      message: "Müşteri eklendi",
      id: result.rows[0].id
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


/*
// müşteri ekleme
router.post("/", async (req, res) => {
  const { name, phone } = req.body;

  try {
    const result = await db.query(
      "INSERT INTO customers (name, phone) VALUES ($1,$2) RETURNING id",
      [name, phone]
    );

    res.json({
      message: "Müşteri eklendi",
      id: result.rows[0].id
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

*/



// müşteri listeleme
router.get("/", async (req, res) => {

  try {
    const result = await db.query(
      "SELECT * FROM customers ORDER BY id ASC"
    );

    res.json(result.rows);

  } catch (err) {
    res.status(500).json({ error: err.message });
  }

});

module.exports = router;