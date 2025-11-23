
-- Transactional logic for booking a single seat

-- Inputs: 
--  customer_id - ID of the customer making the booking
--  flight_id   -ID of the flight
--  seat_number -Seat to be booked (e.g., '1A')
--  total_price - Price of the booking

BEGIN;

-- Lock the seat row to prevent concurrent bookings
WITH locked_seat AS (
    SELECT seat_id, is_available
    FROM seats
    WHERE flight_id = :flight_id AND seat_number = :seat_number
    FOR UPDATE
)

-- Ensure the seat is available
SELECT *
FROM locked_seat
WHERE is_available = TRUE;

-- Insert booking record
INSERT INTO bookings (customer_id, flight_id, total_price, status, booked_at)
VALUES (:customer_id, :flight_id, :total_price, 'CONFIRMED', NOW())
RETURNING booking_id;

-- Insert booking item (link seat to booking)
INSERT INTO booking_items (booking_id, seat_id)
SELECT booking_id, seat_id
FROM locked_seat;

-- Update seat availability
UPDATE seats
SET is_available = FALSE
WHERE flight_id = :flight_id AND seat_number = :seat_number;

COMMIT;


-- Notes:
-- 1. Replace :customer_id, :flight_id, :seat_number, :total_price
--    with parameters from your backend API.
-- 2. Use a single transaction to avoid race conditions.
-- 3. FOR UPDATE ensures no two transactions can book the same seat at the same time.

