const db = require('../db/db');
const fs = require('fs');
const path = require('path');

// SQL scripts (read dynamically)
const singleSeatSQL = fs.readFileSync(path.join(__dirname, '../db_scripts/single_seat_booking.sql'), 'utf-8');
const batchBookingSQL = fs.readFileSync(path.join(__dirname, '../db_scripts/batch_booking.sql'), 'utf-8');
const cancelBookingSQL = fs.readFileSync(path.join(__dirname, '../db_scripts/cancel_booking.sql'), 'utf-8');

// Example function
exports.singleSeatBooking = async (req, res) => {
  const { customer_id, flight_id, seat_number, total_price } = req.body;
  try {
    await db.query('BEGIN');
    await db.query(singleSeatSQL, [customer_id, flight_id, seat_number, total_price]);
    await db.query('COMMIT');
    res.status(200).json({ message: 'Booking successful' });
  } catch (err) {
    await db.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Booking failed' });
  }
};

// Similar functions for batchBooking, cancelBooking...
