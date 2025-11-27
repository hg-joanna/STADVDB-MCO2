-- Unified Single Seat Booking
-- 1. Lock the seat
WITH locked_seat AS (
    SELECT seat_id
    FROM seats
    WHERE flight_id = $2 
      AND seat_number = $3 
      AND is_available = TRUE
    FOR UPDATE
),
-- 2. Insert Booking
insert_booking AS (
    INSERT INTO bookings (customer_id, flight_id, total_price, status, booked_at)
    SELECT $1, $2, $4, 'CONFIRMED', NOW()
    FROM locked_seat -- Only runs if seat was found
    RETURNING booking_id
),
-- 3. Insert Booking Item
insert_item AS (
    INSERT INTO booking_items (booking_id, seat_id)
    SELECT ib.booking_id, ls.seat_id
    FROM insert_booking ib, locked_seat ls
)
-- 4. Mark Seat as Unavailable
UPDATE seats
SET is_available = FALSE
WHERE seat_id IN (SELECT seat_id FROM locked_seat);