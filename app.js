// /server/app.js
const express = require('express');
const cors = require('cors'); // YOU NEED THIS
const app = express();

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Allow React (running on port 5173) to talk to this server (running on port 4000)
app.use(cors({
    origin: 'http://localhost:5173', // or 3000 if using Create React App
    credentials: true
}));

// Routes
const bookingRoutes = require('./routes/bookingRoutes');
const flightRoutes = require('./routes/flightRoutes');
const reportsRoutes = require('./routes/reportsRoutes');

// API Routes
app.use('/api/booking', bookingRoutes);
app.use('/api/flight', flightRoutes);
app.use('/api/reports', reportsRoutes);

// Legacy endpoint for frontend compatibility (/api/report maps to /api/reports/occupancy)
app.get('/api/report', require('./controllers/reportsController').getFlightOccupancy);

// Root endpoint - API documentation
app.get('/', (req, res) => {
    res.json({
        message: 'Flight Booking System API',
        version: '1.0.0',
        endpoints: {
            flights: {
                'GET /api/flight/:id': 'Get flight details',
                'GET /api/flight/:id/seats': 'Get available seats'
            },
            bookings: {
                'POST /api/booking/single': 'Book a single seat',
                'POST /api/booking/batch': 'Book multiple seats',
                'POST /api/booking/cancel': 'Cancel a booking'
            },
            reports: {
                'GET /api/reports/dashboard/summary': 'Dashboard overview',
                'GET /api/reports/revenue/by-route': 'Revenue by route',
                'GET /api/reports/revenue/by-class': 'Revenue by seat class',
                'GET /api/reports/revenue/monthly': 'Monthly revenue trends',
                'GET /api/reports/bookings/lead-time': 'Booking lead time distribution',
                'GET /api/reports/bookings/peak-hours': 'Peak booking hours',
                'GET /api/reports/bookings/patterns': 'Booking patterns',
                'GET /api/reports/customers/segments': 'Customer segments',
                'GET /api/reports/customers/top-spenders': 'Top customers by spend',
                'GET /api/reports/operations/seat-utilization': 'Seat utilization',
                'GET /api/reports/operations/cancellation-rate': 'Cancellation rates',
                'GET /api/reports/operations/load-factor': 'Flight load factors',
                'GET /api/reports/routes/top': 'Top routes'
            }
        },
        documentation: 'See REPORTS_API.md for detailed API documentation',
        status: 'running'
    });
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
    console.log(`Backend Server running at http://localhost:${PORT}`);
});