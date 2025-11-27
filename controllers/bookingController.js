const db = require('../db/db');
const fs = require('fs');
const path = require('path');

// Helper to read SQL files strictly as ONE command
const readSQL = (filename) => {
    return fs.readFileSync(path.join(__dirname, `../db_scripts/${filename}`), 'utf-8').trim();
};

const singleSeatSQL = readSQL('single_seat_booking.sql');
const batchBookingSQL = readSQL('batch_booking.sql');
const cancelBookingSQL = readSQL('cancel_booking.sql');

// Single seat booking
exports.singleSeatBooking = async (req, res) => {
  const { customer_id, flight_id, seat_number, total_price } = req.body;
  
  const client = await db.getClient();
  const params = [customer_id, flight_id, seat_number, total_price];
  
  try {
    await client.query('BEGIN');
    // Execute the entire SQL file as one command
    await client.query(singleSeatSQL, params);
    await client.query('COMMIT');
    res.status(200).json({ message: 'Booking successful' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error("Single Booking Error:", err);
    res.status(500).json({ error: 'Booking failed: ' + err.message });
  } finally {
    client.release();
  }
};

// Batch booking
exports.batchBooking = async (req, res) => {
  const { customer_id, flight_id, seat_numbers, total_price } = req.body;
  
  const client = await db.getClient();
  const params = [customer_id, flight_id, seat_numbers, total_price];
  
  try {
    await client.query('BEGIN');
    // Execute the entire SQL file as one command
    await client.query(batchBookingSQL, params);
    await client.query('COMMIT');
    res.status(200).json({ message: 'Batch booking successful' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error("Batch Booking Error:", err);
    res.status(500).json({ error: 'Batch booking failed: ' + err.message });
  } finally {
    client.release();
  }
};

// Cancel booking
exports.cancelBooking = async (req, res) => {
  const { booking_id } = req.body;
  
  const client = await db.getClient();
  const params = [booking_id];
  
  try {
    await client.query('BEGIN');
    await client.query(cancelBookingSQL, params);
    await client.query('COMMIT');
    res.status(200).json({ message: 'Booking cancelled successfully' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error("Cancel Error:", err);
    res.status(500).json({ error: 'Cancellation failed: ' + err.message });
  } finally {
    client.release();
  }
};