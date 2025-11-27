-- Transactional logic for booking multiple seats

-- Inputs:
--  $1 - customer_id
--  $2 - flight_id
--  $3 - seat_numbers (Array)
--  $4 - total_price

-- 1. Create a CTE that locks all requested seats AND confirms they are available.
WITH locked_available_seats AS (
    SELECT seat_id, seat_number, is_available
    FROM seats
    WHERE flight_id = $2
      AND seat_number = ANY($3) -- Check all requested seat numbers
      AND is_available = TRUE   -- Filter only available seats
    FOR UPDATE
),

-- 2. Insert the booking record. This CTE runs ONLY if the next step succeeds.
insert_booking AS (
    INSERT INTO bookings (customer_id, flight_id, total_price, status, booked_at)
    -- Important: We check if the count of available seats matches the count requested
    -- If it doesn't match, this subquery will return 0 rows and the INSERT will fail.
    SELECT $1, $2, $4, 'CONFIRMED', NOW()
    FROM (
        SELECT COUNT(*) as count FROM locked_available_seats
    ) sub
    WHERE sub.count = array_length($3, 1)
    RETURNING booking_id
)

-- 3. Insert booking items using the newly created booking_id and the locked seats
insert_items AS (
    INSERT INTO booking_items (booking_id, seat_id)
    SELECT ib.booking_id, las.seat_id
    FROM insert_booking ib, locked_available_seats las
    RETURNING seat_id
) -- Note: ib is only present if the previous INSERT succeeded

-- 4. Update seat availability (now simplified to use the list of successfully locked seats)
UPDATE seats
SET is_available = FALSE
WHERE seat_id IN (SELECT seat_id FROM locked_available_seats);