const express = require('express');
const router = express.Router();


const flightController = require('../controllers/flightController');


router.get('/', flightController.getAllFlights); // NEW: Get all flights
router.get('/:flight_id', flightController.getFlightDetails);
router.get('/:flight_id/seats', flightController.getAvailableSeats);

module.exports = router;