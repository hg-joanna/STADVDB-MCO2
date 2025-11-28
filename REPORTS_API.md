# Reports API Documentation

Base URL: `http://localhost:4000/api/reports`

All endpoints return JSON data from the OLAP data warehouse.

---

## 📊 Revenue Reports

### Get Revenue by Route
**GET** `/revenue/by-route`

Returns top 10 routes by revenue with booking statistics.

**Response:**
```json
[
  {
    "route_code": "MNL-CEB",
    "origin": "Manila",
    "destination": "Cebu",
    "total_bookings": 150,
    "total_revenue": 750000.00,
    "avg_price_per_seat": 5000.00,
    "revenue_after_cancellations": 700000.00
  }
]
```

---

### Get Revenue by Seat Class
**GET** `/revenue/by-class`

Returns revenue breakdown by seat class (Economy/Business).

**Response:**
```json
[
  {
    "seat_class": "ECONOMY",
    "seats_booked": 450,
    "total_revenue": 2250000.00,
    "avg_price": 5000.00,
    "min_price": 3000.00,
    "max_price": 7000.00
  }
]
```

---

### Get Monthly Revenue
**GET** `/revenue/monthly?year=2025`

Returns monthly revenue trends for a specific year.

**Query Parameters:**
- `year` (optional): Year to filter (default: 2025)

**Response:**
```json
[
  {
    "year": 2025,
    "month": 12,
    "month_name": "December",
    "bookings": 85,
    "revenue": 425000.00,
    "cancelled_revenue": 25000.00,
    "cancellation_rate_pct": 5.88
  }
]
```

---

## 📅 Booking Analytics

### Get Booking Lead Time Distribution
**GET** `/bookings/lead-time`

Shows how far in advance customers book their flights.

**Response:**
```json
[
  {
    "lead_time_bucket": "0-1 days",
    "booking_count": 45,
    "percentage": 15.50
  },
  {
    "lead_time_bucket": "2-3 days",
    "booking_count": 78,
    "percentage": 26.80
  }
]
```

---

### Get Peak Booking Hours
**GET** `/bookings/peak-hours`

Returns booking activity by hour of day (0-23).

**Response:**
```json
[
  {
    "booking_hour": 9,
    "bookings": 45,
    "revenue": 225000.00,
    "booking_percentage": 12.30
  }
]
```

---

### Get Booking Patterns (Weekend vs Weekday)
**GET** `/bookings/patterns`

Compares booking behavior on weekends vs weekdays.

**Response:**
```json
[
  {
    "is_weekend": false,
    "period_type": "Weekday",
    "bookings": 280,
    "revenue": 1400000.00,
    "avg_price": 5000.00
  },
  {
    "is_weekend": true,
    "period_type": "Weekend",
    "bookings": 120,
    "revenue": 600000.00,
    "avg_price": 5000.00
  }
]
```

---

## 👥 Customer Analytics

### Get Customer Segments
**GET** `/customers/segments`

Returns customer segmentation analysis (VIP, Regular, One-time).

**Response:**
```json
[
  {
    "customer_segment": "VIP",
    "customer_count": 15,
    "total_bookings": 180,
    "total_revenue": 1200000.00,
    "avg_booking_value": 6666.67,
    "revenue_share_pct": 45.50
  }
]
```

---

### Get Top Customers
**GET** `/customers/top-spenders?limit=20`

Returns top customers by total spend.

**Query Parameters:**
- `limit` (optional): Number of customers to return (default: 20)

**Response:**
```json
[
  {
    "customer_id": 42,
    "full_name": "John Doe",
    "email": "john@example.com",
    "customer_segment": "VIP",
    "total_bookings": 25,
    "total_spent": 150000.00,
    "avg_booking_value": 6000.00,
    "first_booking_date": "2025-01-15",
    "last_booking_date": "2025-11-20"
  }
]
```

---

## ⚙️ Operational Metrics

### Get Seat Utilization by Class
**GET** `/operations/seat-utilization`

Current seat utilization for today's flights.

**Response:**
```json
[
  {
    "seat_class": "ECONOMY",
    "total_seats": 800,
    "available_seats": 320,
    "booked_seats": 480,
    "utilization_pct": 60.00
  }
]
```

---

### Get Cancellation Rate by Route
**GET** `/operations/cancellation-rate`

Cancellation rates for each route.

**Response:**
```json
[
  {
    "route_code": "MNL-CEB",
    "origin": "Manila",
    "destination": "Cebu",
    "total_bookings": 150,
    "cancelled_bookings": 8,
    "cancellation_rate_pct": 5.33
  }
]
```

---

### Get Load Factor
**GET** `/operations/load-factor`

Shows flight capacity and seat sales (% seats sold).

**Response:**
```json
[
  {
    "flight_number": "FL001",
    "route_code": "MNL-CEB",
    "departure_time": "2025-12-01T08:00:00Z",
    "total_seats": 100,
    "booked_seats": 85,
    "available_seats": 15,
    "load_factor_pct": 85.00
  }
]
```

---

## 🛫 Route Analytics

### Get Top Routes
**GET** `/routes/top`

Top 10 routes by flight volume and revenue.

**Response:**
```json
[
  {
    "route_code": "MNL-CEB",
    "origin": "Manila",
    "destination": "Cebu",
    "total_flights": 45,
    "total_bookings": 3500,
    "total_revenue": 17500000.00
  }
]
```

---

## 📈 Dashboard Summary

### Get Dashboard Summary
**GET** `/dashboard/summary`

Returns key metrics for dashboard overview.

**Response:**
```json
{
  "totalRevenue": {
    "total_revenue": 5250000.00
  },
  "totalBookings": {
    "total_bookings": 1050
  },
  "totalCustomers": {
    "total_customers": 500
  },
  "avgBookingValue": {
    "avg_booking_value": 5000.00
  },
  "currentUtilization": {
    "utilization_pct": 65.50
  },
  "cancellationRate": {
    "cancellation_rate": 4.20
  }
}
```

---

## 🚀 Usage Examples

### JavaScript/Fetch
```javascript
// Get revenue by route
fetch('http://localhost:4000/api/reports/revenue/by-route')
  .then(res => res.json())
  .then(data => console.log(data));

// Get monthly revenue for 2025
fetch('http://localhost:4000/api/reports/revenue/monthly?year=2025')
  .then(res => res.json())
  .then(data => console.log(data));
```

### React Example
```jsx
import { useEffect, useState } from 'react';

function RevenueReport() {
  const [data, setData] = useState([]);

  useEffect(() => {
    fetch('http://localhost:4000/api/reports/revenue/by-route')
      .then(res => res.json())
      .then(setData);
  }, []);

  return (
    <div>
      {data.map(route => (
        <div key={route.route_code}>
          <h3>{route.route_code}</h3>
          <p>Revenue: ${route.total_revenue}</p>
        </div>
      ))}
    </div>
  );
}
```

### cURL
```bash
# Get dashboard summary
curl http://localhost:4000/api/reports/dashboard/summary

# Get top customers (limit 10)
curl "http://localhost:4000/api/reports/customers/top-spenders?limit=10"

# Get monthly revenue
curl "http://localhost:4000/api/reports/revenue/monthly?year=2025"
```

---

## 📝 Notes

- All reports query the **Reports Database** (OLAP) on port 5434
- Data is updated via **logical replication** from the Primary DB
- **ETL pipeline** transforms OLTP data into star schema for analytics
- For real-time data, run ETL: `docker compose exec reports_db psql -U postgres -d flight_booking_reports -f /docker-entrypoint-initdb.d/etl_master_pipeline.sql`

---

## 🔧 Error Handling

All endpoints return standard error responses:

```json
{
  "error": "Failed to fetch revenue by route"
}
```

HTTP Status Codes:
- `200`: Success
- `500`: Server error (check logs with `docker compose logs app_server`)
