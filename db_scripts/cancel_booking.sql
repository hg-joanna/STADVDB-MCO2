
-- Transactional logic for cancelling a booking

-- Inputs:
--  :booking_id  - ID of the booking to cancel

BEGIN;

-- Lock the booking row to prevent concurrent modification
WITH locked_booking AS (
    SELECT booking_id, status
    FROM bookings
    WHERE booking_id = :booking_id
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

-- Lock all associated seats
WITH locked_seats AS (
    SELECT s.seat_id
    FROM booking_items bi
    JOIN seats s ON bi.seat_id = s.seat_id
    WHERE bi.booking_id = :booking_id
    FOR UPDATE
)
-- Mark seats as available
UPDATE seats
SET is_available = TRUE
WHERE seat_id IN (SELECT seat_id FROM locked_seats);

-- Update booking status to CANCELLED
UPDATE bookings
SET status = 'CANCELLED'
WHERE booking_id = :booking_id;

COMMIT;

-- Notes:
-- 1. Wraps the entire operation in a transaction to avoid race conditions.
-- 2. FOR UPDATE locks both booking and seat rows.
-- 3. Backend should pass the booking_id to cancel.
-- 4. Ensures seats are freed and booking marked as cancelled atomically.

