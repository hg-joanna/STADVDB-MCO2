
-- Transactional logic for booking multiple seats

-- Inputs:
--  customer_id   -ID of the customer making the booking
--  flight_id     - ID of the flight
--  seat_numbers  - Array of seat_numbers to book (e.g., ['1A','1B','2A'])
--  total_price  - Total price for all seats in the booking

BEGIN;

-- Lock all selected seats for this flight
WITH locked_seats AS (
    SELECT seat_id, seat_number, is_available
    FROM seats
    WHERE flight_id = :flight_id
      AND seat_number = ANY(:seat_numbers)
    FOR UPDATE
)
--  Ensure all seats are available
SELECT *
FROM locked_seats
WHERE is_available = TRUE;

-- Raise exception if some seats are not available
DO $$
BEGIN
  IF (SELECT COUNT(*) FROM locked_seats) <> array_length(:seat_numbers, 1) THEN
    RAISE EXCEPTION 'One or more selected seats are already booked';
  END IF;
END$$;

-- Insert booking record
INSERT INTO bookings (customer_id, flight_id, total_price, status, booked_at)
VALUES (:customer_id, :flight_id, :total_price, 'CONFIRMED', NOW())
RETURNING booking_id;

-- Insert booking items for all seats
INSERT INTO booking_items (booking_id, seat_id)
SELECT booking_id, seat_id
FROM locked_seats;

-- Update seat availability for all seats
UPDATE seats
SET is_available = FALSE
WHERE flight_id = :flight_id
  AND seat_number = ANY(:seat_numbers);

COMMIT;


-- Notes:
-- 1. Use :seat_numbers as an array of seat_numbers from backend API.
-- 2. Entire operation is in one transaction to avoid race conditions.
-- 3. FOR UPDATE locks all selected seats so no other transaction can book them simultaneously.
-- 4. Optional check ensures all seats are available before committing.
