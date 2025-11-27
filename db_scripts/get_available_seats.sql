-- Fetch all available seats for a given flight

-- Input:
--  flight_id - ID of the flight

SELECT 
    s.seat_id,
    s.seat_number,
    s.seat_class
FROM seats s
WHERE s.flight_id = $1
  AND s.is_available = TRUE
ORDER BY s.seat_number;
