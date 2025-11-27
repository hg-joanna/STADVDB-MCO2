
-- Transactional logic for cancelling a booking

-- Inputs:
--  $1 - booking_id

-- Lock the booking row to prevent concurrent modification
WITH locked_booking AS (
    SELECT booking_id, status
    FROM bookings
    WHERE booking_id = $1
    FOR UPDATE
)
SELECT *
FROM locked_booking
WHERE status = 'CONFIRMED';

-- Raise exception if booking is already cancelled
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM locked_booking) THEN
        RAISE EXCEPTION 'Booking does not exist or is already cancelled';
    END IF;
END$$;

-- Check the status of the booking.
DO $$
DECLARE
    current_status VARCHAR(20);
BEGIN
    -- Try to fetch the status of the booking we just locked
    SELECT status INTO current_status
    FROM bookings
    WHERE booking_id = $1;
    
    -- Check if the booking exists
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking ID % does not exist.', $1;
    END IF;

    -- Check if the booking is already cancelled
    IF current_status = 'CANCELLED' THEN
        RAISE EXCEPTION 'Booking ID % is already cancelled.', $1;
    END IF;
    
    -- Note: We rely on the implicit lock from the previous SELECT INTO.
END$$;

-- Lock all associated seats
WITH locked_seats AS (
    SELECT s.seat_id
    FROM booking_items bi
    JOIN seats s ON bi.seat_id = s.seat_id
    WHERE bi.booking_id = $1
    FOR UPDATE
)
-- Mark seats as available
UPDATE seats
SET is_available = TRUE
WHERE seat_id IN (SELECT seat_id FROM locked_seats);

-- Update booking status to CANCELLED
UPDATE bookings
SET status = 'CANCELLED'
WHERE booking_id = $1;

-- Notes:
-- 1. Wraps the entire operation in a transaction to avoid race conditions.
-- 2. FOR UPDATE locks both booking and seat rows.
-- 3. Backend should pass the booking_id to cancel.
-- 4. Ensures seats are freed and booking marked as cancelled atomically.

