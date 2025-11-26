
-- Fetch flight details including departure, arrival, and route

-- Input:
--  flight_id - ID of the flight

SELECT 
    f.flight_id,
    f.flight_number,
    f.origin,
    f.destination,
    f.departure_time,
    f.arrival_time
FROM flights f
WHERE f.flight_id = $1;
