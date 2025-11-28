-- Unified Single Seat Booking
WITH locked_seat AS (
    SELECT seat_id, 
           CASE WHEN seat_class = 'BUSINESS' THEN 10000 ELSE 5000 END as price
    FROM seats
    WHERE flight_id = $2 
      AND seat_number = $3 
      AND is_available = TRUE
    FOR UPDATE
),
insert_booking AS (
    INSERT INTO bookings (customer_id, flight_id, total_price, status, booked_at)
    SELECT $1, $2, $4, 'CONFIRMED', NOW()
    FROM locked_seat
    RETURNING booking_id
),
insert_item AS (
    INSERT INTO booking_items (booking_id, seat_id, price)
    SELECT ib.booking_id, ls.seat_id, ls.price
    FROM insert_booking ib, locked_seat ls
)
UPDATE seats
SET is_available = FALSE
WHERE seat_id IN (SELECT seat_id FROM locked_seat);