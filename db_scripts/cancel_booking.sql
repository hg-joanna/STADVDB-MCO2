-- Unified Cancel Booking
WITH target_booking AS (
    SELECT booking_id 
    FROM bookings 
    WHERE booking_id = $1 AND status != 'CANCELLED'
    FOR UPDATE
),
updated_booking AS (
    UPDATE bookings
    SET status = 'CANCELLED'
    WHERE booking_id IN (SELECT booking_id FROM target_booking)
    RETURNING booking_id
),
freed_seats AS (
    SELECT seat_id 
    FROM booking_items 
    WHERE booking_id IN (SELECT booking_id FROM target_booking)
)
UPDATE seats
SET is_available = TRUE
WHERE seat_id IN (SELECT seat_id FROM freed_seats);