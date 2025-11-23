const express = require('express');
const router = express.Router();

// Controller
const flightController = require('../controllers/flightController');

// Routes
router.get('/:flight_id', flightController.getFlightDetails);
router.get('/:flight_id/seats', flightController.getAvailableSeats);

module.exports = router;
