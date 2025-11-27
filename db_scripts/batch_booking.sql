-- Unified Batch Booking
-- 1. Lock available seats
WITH locked_available_seats AS (
    SELECT seat_id, price -- <--- ADDED price here
    FROM seats
    WHERE flight_id = $2
      AND seat_number = ANY($3) -- Matches array of seat numbers
      AND is_available = TRUE
    FOR UPDATE
),
-- 2. Insert Booking
insert_booking AS (
    INSERT INTO bookings (customer_id, flight_id, total_price, status, booked_at)
    SELECT $1, $2, $4, 'CONFIRMED', NOW()
    FROM (
        -- Ensure we found ALL the requested seats
        SELECT COUNT(*) as count FROM locked_available_seats
    ) sub
    WHERE sub.count = array_length($3, 1)
    RETURNING booking_id
),
-- 3. Insert Booking Items
insert_items AS (
    INSERT INTO booking_items (booking_id, seat_id, price) -- <--- ADDED price column
    SELECT ib.booking_id, las.seat_id, las.price         -- <--- ADDED price value
    FROM insert_booking ib, locked_available_seats las
    RETURNING seat_id
)
-- 4. Mark Seats as Unavailable
UPDATE seats
SET is_available = FALSE
WHERE seat_id IN (SELECT seat_id FROM insert_items);