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

// These remain exactly the same
app.use('/api/booking', bookingRoutes);
app.use('/api/flight', flightRoutes);

// DELETE the app.get('/') redirect. 
// React handles the homepage now, not Express.

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
    console.log(`Backend Server running at http://localhost:${PORT}`);
});