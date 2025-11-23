const db = require('../db/db');
const fs = require('fs');
const path = require('path');

const getFlightDetailsSQL = fs.readFileSync(path.join(__dirname, '../db_scripts/get_flight_details.sql'), 'utf-8');
const getAvailableSeatsSQL = fs.readFileSync(path.join(__dirname, '../db_scripts/get_available_seats.sql'), 'utf-8');

exports.getFlightDetails = async (req, res) => {
  const flight_id = req.params.flight_id;
  try {
    const result = await db.query(getFlightDetailsSQL, [flight_id]);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to get flight details' });
  }
};

exports.getAvailableSeats = async (req, res) => {
  const flight_id = req.params.flight_id;
  try {
    const result = await db.query(getAvailableSeatsSQL, [flight_id]);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to get available seats' });
  }
};
