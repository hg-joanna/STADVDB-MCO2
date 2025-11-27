const db = require('../db/db');
const fs = require('fs');
const path = require('path');


const getFlightDetailsSQL = fs.readFileSync(path.join(__dirname, '../db_scripts/get_flight_details.sql'), 'utf-8').trim();
//const getAvailableSeatsSQL = fs.readFileSync(path.join(__dirname, '../db_scripts/get_available_seats.sql'), 'utf-8').trim();

const getAllFlightsSQL = fs.readFileSync(path.join(__dirname, '../db_scripts/get_all_flights.sql'), 'utf-8').trim();


exports.getAllFlights = async (req, res) => {
  try {
    const result = await db.query(getAllFlightsSQL);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to get flights' });
  }
};

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


  const FIXED_SQL = `
    SELECT 
        s.seat_id,
        s.seat_number,
        s.seat_class,
        s.price,
        s.is_available
    FROM seats s
    WHERE s.flight_id = $1
      AND s.is_available = TRUE
    ORDER BY s.seat_number;
  `.trim();

  try {
    const result = await db.query(FIXED_SQL, [flight_id]);
    //const result = await db.query(getAvailableSeatsSQL, [flight_id]);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to get available seats' });
  }
};