const express = require('express');
const router = express.Router();
const reportsController = require('../controllers/reportsController');

// =====================================================
// REVENUE REPORTS
// =====================================================
router.get('/revenue/by-route', reportsController.getRevenueByRoute);
router.get('/revenue/by-class', reportsController.getRevenueBySeatClass);
router.get('/revenue/monthly', reportsController.getMonthlyRevenue);

// =====================================================
// BOOKING ANALYTICS
// =====================================================
router.get('/bookings/lead-time', reportsController.getBookingLeadTime);
router.get('/bookings/peak-hours', reportsController.getPeakBookingHours);
router.get('/bookings/patterns', reportsController.getBookingPatterns);

// =====================================================
// CUSTOMER ANALYTICS
// =====================================================
router.get('/customers/segments', reportsController.getCustomerSegments);
router.get('/customers/top-spenders', reportsController.getTopCustomers);

// =====================================================
// OPERATIONAL METRICS
// =====================================================
router.get('/operations/seat-utilization', reportsController.getSeatUtilization);
router.get('/operations/cancellation-rate', reportsController.getCancellationRate);
router.get('/operations/load-factor', reportsController.getLoadFactor);

// =====================================================
// ROUTE ANALYTICS
// =====================================================
router.get('/routes/top', reportsController.getTopRoutes);

// =====================================================
// DASHBOARD
// =====================================================
router.get('/dashboard/summary', reportsController.getDashboardSummary);

// =====================================================
// ETL MANAGEMENT
// =====================================================
router.post('/etl/refresh', reportsController.refreshWarehouse);

// =====================================================
// LEGACY/FRONTEND COMPATIBILITY
// =====================================================
router.get('/occupancy', reportsController.getFlightOccupancy);

module.exports = router;
