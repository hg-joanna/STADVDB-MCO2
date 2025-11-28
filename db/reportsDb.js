// PostgreSQL connection for Reports Database (OLAP)

const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.REPORTS_POSTGRES_USER || 'postgres',
  host: process.env.REPORTS_DATABASE_HOST || 'reports_db',
  database: process.env.REPORTS_POSTGRES_DB || 'flight_booking_reports',
  password: process.env.REPORTS_POSTGRES_PASSWORD || 'yourpassword',
  port: process.env.REPORTS_DATABASE_PORT || 5432,
});

module.exports = {
  query: (text, params) => pool.query(text, params),
  pool,
};
