const db = require('../db/db');
const reportsDb = require('../db/reportsDb');
const fs = require('fs');
const path = require('path');

// Helper to trigger ETL refresh asynchronously
const triggerETLRefresh = async () => {
  try {
    const etlPath = path.join(__dirname, '../warehouse/etl_master_pipeline.sql');
    if (fs.existsSync(etlPath)) {
      const etlScript = fs.readFileSync(etlPath, 'utf-8');
      // Run in background, don't await
      reportsDb.query(etlScript)
        .then(() => console.log('✓ Warehouse ETL refresh completed'))
        .catch(err => console.error('⚠ ETL refresh failed:', err.message));
    }
  } catch (err) {
    console.error('⚠ ETL trigger error:', err.message);
  }
};

// Helper to read SQL files strictly as ONE command
const readSQL = (filename) => {
    // Try multiple paths to ensure we find the file
    const pathsToTry = [
        path.join(__dirname, `../db_scripts/${filename}`),
        path.join(__dirname, `../../db_scripts/${filename}`),
        path.join(__dirname, `db_scripts/${filename}`)
    ];

    for (const p of pathsToTry) {
        if (fs.existsSync(p)) {
            return fs.readFileSync(p, 'utf-8').trim();
        }
    }
    // Critical error if SQL file is missing
    throw new Error(`Missing SQL file: ${filename}`);
};

const singleSeatSQL = readSQL('single_seat_booking.sql');
const batchBookingSQL = readSQL('batch_booking.sql');
const cancelBookingSQL = readSQL('cancel_booking.sql');

// Helper to handle Database Errors
const handleDbError = (err, res, context) => {
  console.error(`${context} Error:`, err);
  
  if (err.code === '23503') {
    if (err.detail && err.detail.includes('customer_id')) {
      return res.status(400).json({ error: 'Invalid Customer ID. This customer does not exist.' });
    }
    return res.status(400).json({ error: 'Invalid ID provided (Flight or Seat).' });
  }

  if (err.code === '23505') {
    return res.status(409).json({ error: 'One or more seats are already booked.' });
  }

  res.status(500).json({ error: 'Booking failed: ' + err.message });
};

// Single seat booking
exports.singleSeatBooking = async (req, res) => {
  let { customer_id, flight_id, seat_number, total_price } = req.body;
  const client = await db.getClient();
  
  try {
    // 1. FORCE CONVERT TO INTEGERS (Fixes the type mismatch bug)
    customer_id = parseInt(customer_id);
    flight_id = parseInt(flight_id);
    

    // 2. LOG THE VALUES (Check your terminal to see these!)
    console.log(`--- ATTEMPTING SINGLE BOOKING ---`);
    console.log(`Customer: ${customer_id}, Flight: ${flight_id}, Seat: ${seat_number}, Price: ${total_price}`);

    await client.query('BEGIN');
    
    // Execute Transaction
    const result = await client.query(singleSeatSQL, [customer_id, flight_id, seat_number, total_price]);
    
    // 3. CHECK RESULT
    if (result.rowCount === 0) {
       console.log("!!! FAILED: Database found 0 matching rows to update.");
       throw new Error("Seat unavailable or invalid flight details.");
    }

    await client.query('COMMIT');
    console.log(">>> SUCCESS: Booking Confirmed.");
    
    // Trigger ETL refresh asynchronously (don't wait for it)
    triggerETLRefresh();
    
    res.status(200).json({ message: 'Booking successful' });

  } catch (err) {
    await client.query('ROLLBACK');
    handleDbError(err, res, "Single Booking");
  } finally {
    client.release();
  }
};

// Batch booking
exports.batchBooking = async (req, res) => {
  let { customer_id, flight_id, seat_numbers, total_price } = req.body;
  const client = await db.getClient();
  
  try {
    // Force Integers
    customer_id = parseInt(customer_id);
    flight_id = parseInt(flight_id);
    // seat_numbers is an array, ensure all items are numbers
    const safe_seat_numbers = seat_numbers

    console.log(`--- ATTEMPTING BATCH BOOKING ---`);
    console.log(`Customer: ${customer_id}, Flight: ${flight_id}, Seats: ${safe_seat_numbers}`);

    await client.query('BEGIN');
    const result = await client.query(batchBookingSQL, [customer_id, flight_id, safe_seat_numbers, total_price]);

    if (result.rowCount === 0) {
       throw new Error("One or more seats are unavailable.");
    }

    await client.query('COMMIT');
    
    // Trigger ETL refresh asynchronously (don't wait for it)
    triggerETLRefresh();
    
    res.status(200).json({ message: 'Batch booking successful' });

  } catch (err) {
    await client.query('ROLLBACK');
    handleDbError(err, res, "Batch Booking");
  } finally {
    client.release();
  }
};

// Cancel booking
exports.cancelBooking = async (req, res) => {
  const { booking_id } = req.body;
  const client = await db.getClient();
  try {
    await client.query('BEGIN');
    await client.query(cancelBookingSQL, [parseInt(booking_id)]);
    await client.query('COMMIT');
    
    // Trigger ETL refresh asynchronously (don't wait for it)
    triggerETLRefresh();
    
    res.status(200).json({ message: 'Booking cancelled successfully' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error("Cancel Error:", err);
    res.status(500).json({ error: 'Cancellation failed' });
  } finally {
    client.release();
  }
};