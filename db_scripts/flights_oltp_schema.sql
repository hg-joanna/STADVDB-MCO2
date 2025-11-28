--  Flights
CREATE TABLE IF NOT EXISTS flights (
    flight_id SERIAL PRIMARY KEY,
    flight_number VARCHAR(10) NOT NULL,
    origin TEXT NOT NULL,
    destination TEXT NOT NULL,
    departure_time TIMESTAMPTZ NOT NULL,
    arrival_time TIMESTAMPTZ NOT NULL,
    
    CONSTRAINT unique_flight UNIQUE (flight_number, origin, destination, departure_time)
);

CREATE INDEX IF NOT EXISTS idx_flights_route ON flights(origin, destination);
CREATE INDEX IF NOT EXISTS idx_flights_departure_time ON flights(departure_time);

-- Seats
CREATE TABLE IF NOT EXISTS seats (
    seat_id SERIAL PRIMARY KEY,
    flight_id INT NOT NULL REFERENCES flights(flight_id) ON DELETE CASCADE,
    seat_number VARCHAR(5) NOT NULL, -- e.g., 12A
    seat_class VARCHAR(20) NOT NULL CHECK (seat_class IN ('ECONOMY', 'BUSINESS')),
    price NUMERIC(10,2) NOT NULL,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT unique_seat_per_flight UNIQUE (flight_id, seat_number)
);

CREATE INDEX IF NOT EXISTS idx_seats_flight ON seats(flight_id);
CREATE INDEX IF NOT EXISTS idx_seats_availability ON seats(flight_id, is_available);


-- 3. Customers
CREATE TABLE IF NOT EXISTS customers (
    customer_id SERIAL PRIMARY KEY,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE,
    phone TEXT
);


-- Bookings
CREATE TABLE IF NOT EXISTS bookings (
    booking_id SERIAL PRIMARY KEY,
    booking_reference UUID NOT NULL DEFAULT gen_random_uuid(),
    customer_id INT REFERENCES customers(customer_id),
    flight_id INT NOT NULL REFERENCES flights(flight_id),
    total_price NUMERIC(10,2) NOT NULL,
    booked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'CONFIRMED'
        CHECK (status IN ('CONFIRMED', 'CANCELLED'))
);

CREATE INDEX IF NOT EXISTS idx_bookings_flight ON bookings(flight_id);
CREATE INDEX IF NOT EXISTS idx_bookings_customer ON bookings(customer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_booked_at ON bookings(booked_at);

-- Booking Items (Each seat booked)
CREATE TABLE IF NOT EXISTS booking_items (
    booking_item_id SERIAL PRIMARY KEY,
    booking_id INT NOT NULL REFERENCES bookings(booking_id) ON DELETE CASCADE,
    seat_id INT NOT NULL REFERENCES seats(seat_id),
    price NUMERIC(10,2) NOT NULL,

    CONSTRAINT unique_seat_booking UNIQUE (booking_id, seat_id)
);

CREATE INDEX IF NOT EXISTS idx_booking_items_seat ON booking_items(seat_id);
