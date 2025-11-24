# OLAP Data Warehouse Design for Airline Booking System

## 1. Dimension and Fact Table Identification

### **Dimensions** (Descriptive Context)
1. **dim_customer** - Who made the booking
2. **dim_flight** - Which flight was booked
3. **dim_route** - Origin-destination pairs (derived from flights)
4. **dim_seat** - Seat characteristics (class, number)
5. **dim_date** - Time dimension for temporal analysis
6. **dim_time** - Time of day for departure/arrival analysis

### **Facts** (Measurable Events)
1. **fact_bookings** - Booking transactions with revenue metrics
2. **fact_seat_inventory** - Daily snapshot of seat availability (periodic)
3. **fact_flight_performance** - Aggregated flight metrics (optional)

---

## 2. Star Schema Structure with Grain Definitions

### **fact_bookings**
**Grain:** One row per booking item (each seat in a booking)
- **Dimensions:** customer, flight, seat, booking_date, departure_date
- **Measures:** 
  - price (per seat)
  - is_cancelled (flag)
  - booking_to_departure_days (derived metric)
- **Aggregations:** Total revenue, booking count, cancellation rate, load factor

### **fact_seat_inventory**
**Grain:** One row per seat per day (snapshot fact table)
- **Dimensions:** flight, seat, snapshot_date
- **Measures:**
  - is_available (flag)
  - is_booked (flag)
  - days_until_departure
- **Aggregations:** Seat utilization, booking velocity, inventory trends

---

## 3. Star Schema Diagram (Conceptual)

```
        dim_customer                dim_date
              |                         |
              |                         |
        [customer_key]            [date_key]
              |                         |
              +--------+       +--------+
                       |       |
                   fact_bookings
                       |       |
              +--------+       +--------+
              |                         |
        [flight_key]             [seat_key]
              |                         |
              |                         |
        dim_flight                  dim_seat
              |
        [route_key]
              |
         dim_route
```

---

## 4. Design Decisions

### **Surrogate Keys**
- All dimension tables use auto-incrementing surrogate keys (e.g., `customer_key`, `flight_key`)
- Fact tables reference surrogate keys for efficient joins
- Natural keys preserved for reference (e.g., `customer_id`, `flight_number`)

### **Slowly Changing Dimensions (SCD)**
- **Type 1 (Overwrite):** Used for dimensions where history isn't critical
  - `dim_customer`: Email and phone updates overwrite
  - `dim_flight`: Minor corrections overwrite
- **Type 2 (Historical):** Could be added later for customer segments or pricing tiers

### **Date/Time Handling**
- Separate `dim_date` for comprehensive date attributes (year, quarter, month, day, weekday)
- Optional `dim_time` for hour-level analysis of booking patterns
- All timestamps stored in UTC, converted for reporting

### **Fact Table Types**
- **Transaction Fact:** `fact_bookings` (additive, immutable after creation)
- **Periodic Snapshot:** `fact_seat_inventory` (daily snapshots for trend analysis)

---

## 5. ETL Strategy

### **Load Order**
1. Load all dimension tables first (dim_customer, dim_flight, dim_route, dim_seat, dim_date)
2. Load fact tables with FK lookups (fact_bookings, fact_seat_inventory)

### **Incremental Loading**
- Use `last_etl_timestamp` metadata table to track watermarks
- Load only new/changed records from OLTP source
- Daily batch jobs for dimension updates and fact loads

### **Data Quality**
- Handle orphaned records (bookings without valid customers/flights)
- Default dimension records for missing/unknown values
- Validation checks before committing to warehouse

---

## 6. Indexing and Partitioning Strategy

### **Indexes**
- Clustered index on date columns for fact tables
- Non-clustered indexes on FK columns (customer_key, flight_key, etc.)
- Composite indexes for common query patterns (origin + destination, date range + route)

### **Partitioning**
- **fact_bookings:** Partition by `booking_date` (monthly or quarterly)
- **fact_seat_inventory:** Partition by `snapshot_date` (monthly)
- Enables efficient data pruning for time-range queries

### **Materialized Views**
- Pre-aggregate common metrics (monthly revenue by route, customer lifetime value)
- Refresh strategy: Daily or on-demand

---

## 7. OLAP Reports Supported

### **Revenue Analysis**
- Total revenue by route, time period, seat class
- Revenue trends over time (daily, monthly, yearly)
- Revenue per available seat mile (RASM)

### **Booking Patterns**
- Advance booking distribution (how far in advance customers book)
- Peak booking times (day of week, hour of day)
- Booking velocity (bookings over time before departure)

### **Customer Analytics**
- Customer lifetime value
- Repeat customer rate
- Customer segmentation by booking frequency/value

### **Operational Metrics**
- Load factor (% seats sold per flight)
- Seat utilization by class (economy vs business)
- Cancellation rates by route/time period

### **Route Performance**
- Most profitable routes
- Demand by origin-destination pair
- Seasonal trends per route

### **Inventory Management**
- Seat availability trends
- Optimal overbooking analysis
- Pricing effectiveness (revenue optimization)

---

## 8. Future Enhancements

- Add `dim_promotion` for discount codes and campaigns
- Add `dim_payment` for payment method analysis
- Include weather/holiday dimensions for external factor analysis
- Real-time data streaming for near-real-time dashboards
- Implement Type 2 SCD for customer demographic changes
