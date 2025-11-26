import React, { useState } from 'react';
import { CreditCard, User, Plane, MapPin } from 'lucide-react';

const Booking = () => {
  const [formData, setFormData] = useState({
    customer_id: '',
    flight_id: '',
    seat_numbers: '',
    total_price: ''
  });
  const [status, setStatus] = useState({ type: '', message: '' });
  const [loading, setLoading] = useState(false);

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.id]: e.target.value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setStatus({ type: '', message: '' });

    const seats = formData.seat_numbers.split(',').map(s => s.trim()).filter(s => s !== "");
    
    // Determine Endpoint based on logic in original HTML
    const url = seats.length === 1 ? "/api/booking/single" : "/api/booking/batch";
    
    const body = {
      customer_id: formData.customer_id,
      flight_id: formData.flight_id,
      total_price: formData.total_price,
      // API expects 'seat_number' for single, 'seat_numbers' array for batch
      ...(seats.length === 1 ? { seat_number: seats[0] } : { seat_numbers: seats })
    };

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body)
      });
      const data = await response.json();
      
      if (response.ok) {
        setStatus({ type: 'success', message: data.message || "Booking confirmed successfully!" });
      } else {
        setStatus({ type: 'error', message: data.error || "Booking failed." });
      }
    } catch (error) {
      setStatus({ type: 'error', message: "Network error. Please try again." });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-8">
      <h2 className="text-2xl font-bold mb-6 text-slate-800">New Flight Booking</h2>
      
      <form onSubmit={handleSubmit} className="space-y-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          
          {/* Customer ID */}
          <div className="space-y-2">
            <label className="text-sm font-medium text-slate-600">Customer ID</label>
            <div className="relative">
              <User className="absolute left-3 top-3 text-slate-400" size={18} />
              <input
                type="number"
                id="customer_id"
                required
                className="w-full pl-10 pr-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition"
                placeholder="1-100"
                onChange={handleChange}
              />
            </div>
          </div>

          {/* Flight ID */}
          <div className="space-y-2">
            <label className="text-sm font-medium text-slate-600">Flight ID</label>
            <div className="relative">
              <Plane className="absolute left-3 top-3 text-slate-400" size={18} />
              <input
                type="number"
                id="flight_id"
                required
                className="w-full pl-10 pr-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition"
                placeholder="Flight ID"
                onChange={handleChange}
              />
            </div>
          </div>

          {/* Seats */}
          <div className="space-y-2 md:col-span-2">
            <label className="text-sm font-medium text-slate-600">Seat Number(s)</label>
            <div className="relative">
              <MapPin className="absolute left-3 top-3 text-slate-400" size={18} />
              <input
                type="text"
                id="seat_numbers"
                required
                className="w-full pl-10 pr-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition"
                placeholder="e.g. 1A or 1A, 2B, 3C"
                onChange={handleChange}
              />
            </div>
            <p className="text-xs text-slate-500">Separate multiple seats with a comma.</p>
          </div>

          {/* Price */}
          <div className="space-y-2 md:col-span-2">
            <label className="text-sm font-medium text-slate-600">Total Price</label>
            <div className="relative">
              <CreditCard className="absolute left-3 top-3 text-slate-400" size={18} />
              <input
                type="number"
                id="total_price"
                required
                className="w-full pl-10 pr-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition"
                placeholder="0.00"
                onChange={handleChange}
              />
            </div>
          </div>
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-3 rounded-lg transition shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {loading ? 'Processing...' : 'Confirm Booking'}
        </button>

        {status.message && (
          <div className={`p-4 rounded-lg text-sm font-medium ${status.type === 'success' ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'}`}>
            {status.message}
          </div>
        )}
      </form>
    </div>
  );
};

export default Booking;