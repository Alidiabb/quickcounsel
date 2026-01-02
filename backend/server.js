const express = require("express");
const cors = require("cors");
const mysql = require("mysql2");
const bcrypt = require("bcrypt");
require("dotenv").config();

const app = express();
app.use(cors());
app.use(express.json());

// MySQL connection (instructor method)
const db = mysql.createConnection({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
});

// connect to database
db.connect((err) => {
  if (err) {
    console.error("MySQL connection error:", err);
    return;
  }
  console.log("MySQL Connected...");
});

// test route
app.get("/health", (req, res) => {
  res.json({ ok: true });
});

// REGISTER route
app.post("/register", async (req, res) => {
  const {
    name,
    email,
    password,
    date_of_birth,
    gender,
    role,
    bar_number,
    member_since,
    specialization_1,
    specialization_2,
  } = req.body;

  if (!name || !email || !password || !date_of_birth || !gender || !role) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  const cleanGender = String(gender).toLowerCase().trim();
  const cleanRole = String(role).toLowerCase().trim();
  const normalizedEmail = String(email).toLowerCase().trim();

  if (!["male", "female"].includes(cleanGender)) {
    return res.status(400).json({ message: "Invalid gender" });
  }

  if (!["client", "lawyer"].includes(cleanRole)) {
    return res.status(400).json({ message: "Invalid role" });
  }

  db.query(
    "SELECT id FROM users WHERE email = ?",
    [normalizedEmail],
    async (err, users) => {
      if (err) return res.status(500).send(err);

      if (users.length > 0) {
        return res.status(409).json({ message: "Email already exists" });
      }

      try {
        const password_hash = await bcrypt.hash(password, 10);

        db.query(
          `INSERT INTO users (name, email, password_hash, date_of_birth, gender, role)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [name, normalizedEmail, password_hash, date_of_birth, cleanGender, cleanRole],
          (err, result) => {
            if (err) return res.status(500).send(err);

            const userId = result.insertId;

            // if client, done
            if (cleanRole !== "lawyer") {
              return res.status(201).json({
                message: "Registered",
                user_id: userId,
              });
            }

            // for lawyer: validate lawyer fields
            if (!bar_number || !member_since || !specialization_1) {
              return res.status(400).json({ message: "Missing lawyer fields" });
            }

            // prevent duplicate bar number
            db.query(
              "SELECT user_id FROM lawyer_profiles WHERE bar_number = ?",
              [bar_number],
              (errCheck, rows) => {
                if (errCheck) return res.status(500).send(errCheck);
                if (rows.length > 0) {
                  return res.status(409).json({ message: "Bar number already exists" });
                }

                db.query(
                  `INSERT INTO lawyer_profiles
                   (user_id, bar_number, member_since, specialization_1, specialization_2, description)
                   VALUES (?, ?, ?, ?, ?, ?)`,
                  [
                    userId,
                    bar_number,
                    member_since,
                    specialization_1,
                    specialization_2 || null,
                    null,
                  ],
                  (err2) => {
                    if (err2) return res.status(500).send(err2);

                    return res.status(201).json({
                      message: "Lawyer registered",
                      user_id: userId,
                    });
                  }
                );
              }
            );
          }
        );
      } catch (e) {
        return res.status(500).json({ message: "Server error" });
      }
    }
  );
});

// LOGIN route
app.post("/login", (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ message: "Missing email or password" });
  }

  const normalizedEmail = String(email).toLowerCase().trim();

  db.query(
    "SELECT id, name, email, password_hash, role FROM users WHERE email = ?",
    [normalizedEmail],
    async (err, users) => {
      if (err) return res.status(500).send(err);

      if (users.length === 0) {
        return res.status(401).json({ message: "Invalid credentials" });
      }

      const user = users[0];

      try {
        const ok = await bcrypt.compare(password, user.password_hash);
        if (!ok) {
          return res.status(401).json({ message: "Invalid credentials" });
        }

        return res.json({
          message: "Logged in",
          user: {
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role,
          },
        });
      } catch (e) {
        return res.status(500).json({ message: "Server error" });
      }
    }
  );
});

// GET lawyers by specialization (client view list)
app.get("/lawyers", (req, res) => {
  const specialization = req.query.specialization;

  if (!specialization) {
    return res.status(400).json({ message: "Missing specialization" });
  }

  const sql = `
    SELECT
      u.id,
      u.name,
      u.email,
      lp.specialization_1,
      lp.specialization_2,
      COALESCE(AVG(r.rating), 0) AS avg_rating
    FROM users u
    INNER JOIN lawyer_profiles lp ON lp.user_id = u.id
    LEFT JOIN lawyer_reviews r ON r.lawyer_user_id = u.id
    WHERE u.role = 'lawyer'
      AND (lp.specialization_1 = ? OR lp.specialization_2 = ?)
    GROUP BY u.id, u.name, u.email, lp.specialization_1, lp.specialization_2
    ORDER BY avg_rating DESC
  `;

  db.query(sql, [specialization, specialization], (err, result) => {
    if (err) return res.status(500).send(err);
    res.json(result);
  });
});

// POST rating (stars only) 1..5
app.post("/rate", (req, res) => {
  const { lawyer_user_id, client_user_id, rating } = req.body;

  if (!lawyer_user_id || !client_user_id || !rating) {
    return res.status(400).json({ message: "Missing fields" });
  }

  const r = parseInt(rating, 10);
  if (isNaN(r) || r < 1 || r > 5) {
    return res.status(400).json({ message: "Rating must be between 1 and 5" });
  }

  const sql = `
    INSERT INTO lawyer_reviews (lawyer_user_id, client_user_id, rating)
    VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE rating = VALUES(rating)
  `;

  db.query(sql, [lawyer_user_id, client_user_id, r], (err) => {
    if (err) return res.status(500).send(err);
    res.json({ message: "Rated" });
  });
});

// GET lawyer profile (for lawyer view + client details view)
app.get("/lawyer/profile", (req, res) => {
  const user_id = req.query.user_id;

  if (!user_id) {
    return res.status(400).json({ message: "Missing user_id" });
  }

  const sql = `
    SELECT
      u.id,
      u.name,
      u.email,
      lp.bar_number,
      lp.member_since,
      lp.specialization_1,
      lp.specialization_2,
      lp.description,
      COALESCE(AVG(r.rating), 0) AS avg_rating
    FROM users u
    INNER JOIN lawyer_profiles lp ON lp.user_id = u.id
    LEFT JOIN lawyer_reviews r ON r.lawyer_user_id = u.id
    WHERE u.id = ? AND u.role = 'lawyer'
    GROUP BY u.id, u.name, u.email, lp.bar_number, lp.member_since,
             lp.specialization_1, lp.specialization_2, lp.description
    LIMIT 1
  `;

  db.query(sql, [user_id], (err, result) => {
    if (err) return res.status(500).send(err);
    if (result.length === 0) return res.status(404).json({ message: "Lawyer not found" });
    res.json(result[0]);
  });
});

// UPDATE lawyer description
app.put("/lawyer/description", (req, res) => {
  const { user_id, description } = req.body;

  if (!user_id) {
    return res.status(400).json({ message: "Missing user_id" });
  }

  const sql = `
    UPDATE lawyer_profiles
    SET description = ?
    WHERE user_id = ?
  `;

  db.query(sql, [description || "", user_id], (err) => {
    if (err) return res.status(500).send(err);
    res.json({ message: "Description updated" });
  });
});

// ADD a lawyer case
app.post("/lawyer/cases", (req, res) => {
  const { lawyer_user_id, title, details } = req.body;

  if (!lawyer_user_id || !title || !details) {
    return res.status(400).json({ message: "Missing fields" });
  }

  const sql = `
    INSERT INTO lawyer_cases (lawyer_user_id, title, details)
    VALUES (?, ?, ?)
  `;

  db.query(sql, [lawyer_user_id, title, details], (err, result) => {
    if (err) return res.status(500).send(err);
    res.status(201).json({ message: "Case added", case_id: result.insertId });
  });
});

// LIST lawyer cases
app.get("/lawyer/cases", (req, res) => {
  const user_id = req.query.user_id;

  if (!user_id) {
    return res.status(400).json({ message: "Missing user_id" });
  }

  const sql = `
    SELECT id, title, details, created_at
    FROM lawyer_cases
    WHERE lawyer_user_id = ?
    ORDER BY created_at DESC
  `;

  db.query(sql, [user_id], (err, result) => {
    if (err) return res.status(500).send(err);
    res.json(result);
  });
});

// start server (LAST)
app.listen(process.env.PORT, () => {
  console.log("Server running on port " + process.env.PORT);
});
