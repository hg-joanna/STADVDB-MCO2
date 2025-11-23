const bookingRoutes = require('./routes/bookingRoutes');
const flightRoutes = require('./routes/flightRoutes');const express = require('express');
const app = express();
const bodyParser = require('body-parser');

// Routes
const bookingRoutes = require('./routes/bookingRoutes');
const flightRoutes = require('./routes/flightRoutes');

app.use(bodyParser.json());

// Use routes
app.use('/booking', bookingRoutes);
app.use('/flights', flightRoutes);

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
