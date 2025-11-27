// bookingController.js (CORRECTED)
const db = require('../db/db');
const fs = require('fs');
const path = require('path');

// Helper function to read and split the SQL into an array of commands
// This resolves the "singleSeatCommands is not defined" error
const readAndSplitSQL = (filename) => {
    const sql = fs.readFileSync(path.join(__dirname, `../db_scripts/${filename}`), 'utf-8');
    // Split by semicolon, trim whitespace, and filter out comments
    return sql
        .split(';')
        .map(cmd => cmd.trim())
        // Filter out empty lines and SQL comments
        .filter(cmd => cmd.length > 0 && !cmd.startsWith('--'));
};

// SQL scripts (now stored as arrays of individual commands)
const singleSeatCommands = readAndSplitSQL('single_seat_booking.sql');
const batchBookingCommands = readAndSplitSQL('batch_booking.sql');
const cancelBookingCommands = readAndSplitSQL('cancel_booking.sql');


// Single seat booking
exports.singleSeatBooking = async (req, res) => {
  const { customer_id, flight_id, seat_number, total_price } = req.body;
  
  const client = await db.getClient(); // Acquire dedicated client
  const params = [customer_id, flight_id, seat_number, total_price];
  
  try {
    // *** FIX: Use client.query() for all transaction control ***
    await client.query('BEGIN');
    
    // Execute each core command individually on the client
    for (const command of singleSeatCommands) {
      // Execute command with the shared parameters
      await client.query(command, params); 
    }
    
    await client.query('COMMIT');
    
    res.status(200).json({ message: 'Booking successful' });
  } catch (err) {
    // *** FIX: Use client.query() for ROLLBACK ***
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Booking failed: ' + err.message });
  } finally{
    // Release the client connection back to the pool
    client.release();
  }
};


// Batch booking
exports.batchBooking = async (req, res) => {
  const { customer_id, flight_id, seat_numbers, total_price } = req.body;
  
  const client = await db.getClient();
  const params = [customer_id, flight_id, seat_numbers, total_price];
  
  try {
    // *** FIX: Use client.query() ***
    await client.query('BEGIN');
    for (const command of batchBookingCommands) {
      await client.query(command, params);
    }
    await client.query('COMMIT');
    res.status(200).json({ message: 'Batch booking successful' });
  } catch (err) {
    // *** FIX: Use client.query() ***
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Batch booking failed: ' + err.message });
  } finally{
    client.release();
  }
};


// Cancel booking
exports.cancelBooking = async (req, res) => {
  const { booking_id } = req.body;
  
  const client = await db.getClient();
  const params = [booking_id];
  
  try {
    // *** FIX: Use client.query() ***
    await client.query('BEGIN');
    for (const command of cancelBookingCommands) {
      await client.query(command, params);
    }
    await client.query('COMMIT');
    res.status(200).json({ message: 'Booking cancelled' });
  } catch (err) {
    // *** FIX: Use client.query() ***
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Cancellation failed: ' + err.message });
  }finally{
    client.release();
  }
};