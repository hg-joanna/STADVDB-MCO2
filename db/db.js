// postGreSQL connection

const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.POSTGRES_USER || 'postgres',
  host: process.env.DATABASE_HOST || 'primary_db',
  database: process.env.POSTGRES_DB || 'flight_booking',
  password: process.env.POSTGRES_PASSWORD || 'yourpassword',
  port: process.env.DATABASE_PORT || 5432,
});

module.exports = {
  query: (text, params) => pool.query(text, params),
  getClient: () => pool.connect(),
  pool,
};
