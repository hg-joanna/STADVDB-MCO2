-- Fetch all available seats for a given flight

-- Input:
--  flight_id - ID of the flight

SELECT 
    s.seat_id,
    s.seat_number,
    s.seat_class,
    s.price,
    s.is_available
FROM seats s
WHERE s.flight_id = $1

-- Fix: Sort by length first (puts '1A' before '10A'), then by the text
ORDER BY LENGTH(s.seat_number), s.seat_number;