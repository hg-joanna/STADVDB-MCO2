const express = require('express');
const router = express.Router();

// Controller
const bookingController = require('../controllers/bookingController');

// Routes
router.post('/single', bookingController.singleSeatBooking);
router.post('/batch', bookingController.batchBooking);
router.post('/cancel', bookingController.cancelBooking);

module.exports = router;
