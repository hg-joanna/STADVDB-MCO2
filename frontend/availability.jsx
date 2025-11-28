import React, { useState, useEffect } from 'react';
import { Search } from 'lucide-react';

const Availability = () => {
  const [flightId, setFlightId] = useState('');
  const [flights, setFlights] = useState([]); // Store list of flights
  const [seats, setSeats] = useState([]);
  const [hasSearched, setHasSearched] = useState(false);

  const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '';

  // 1. Fetch all flights when the component mounts
  useEffect(() => {
    const fetchFlights = async () => {
      try {
        const response = await fetch(`${API_BASE}/api/flight`);
        if (response.ok) {
          const data = await response.json();
          setFlights(data);
        } else {
          console.error("Failed to fetch flight list");
        }
      } catch (error) {
        console.error("Error connecting to server:", error);
      }
    };

    fetchFlights();
  }, []);

  const checkSeats = async () => {
    if (!flightId) return;
    try {
      const response = await fetch(`${API_BASE}/api/flight/${flightId}/seats`);
      const data = await response.json();
      setSeats(data);
      setHasSearched(true);
    } catch (error) {
      console.error("Failed to fetch seats");
    }
  };

  return (
    <div className="space-y-6">
      <div className="bg-white p-6 rounded-xl shadow-sm border border-slate-200 flex flex-col md:flex-row gap-4 items-end">
        <div className="flex-1 w-full">
          <label className="block text-sm font-medium text-slate-600 mb-2">Select Flight</label>
          
          {/* 2. Replaced Input with Select Dropdown */}
          <select
            value={flightId}
            onChange={(e) => setFlightId(e.target.value)}
            className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none bg-white"
          >
            <option value="">-- Choose a Flight --</option>
            {flights.map((flight) => (
              <option key={flight.flight_id} value={flight.flight_id}>
                {/* Display Flight Number and Route */}
                {flight.flight_number}: {flight.origin} ➝ {flight.destination}
              </option>
            ))}
          </select>

        </div>
        <button 
          onClick={checkSeats}
          disabled={!flightId} // Disable button if no flight selected
          className={`px-6 py-2 rounded-lg transition flex items-center gap-2 ${
            !flightId 
              ? 'bg-slate-300 text-slate-500 cursor-not-allowed' 
              : 'bg-slate-800 text-white hover:bg-slate-900'
          }`}
        >
          <Search size={18} /> Check Availability
        </button>
      </div>

      {hasSearched && (
        <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
          <table className="w-full text-left border-collapse">
            <thead className="bg-slate-50 border-b border-slate-200">
              <tr>
                <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase">Seat</th>
                <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase">Class</th>
                <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase">Price</th>
                <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {seats.length > 0 ? seats.map((s, idx) => (
                <tr key={idx} className="hover:bg-slate-50">
                  <td className="px-6 py-4 font-medium text-slate-900">{s.seat_number}</td>
                  <td className="px-6 py-4 text-slate-600">{s.seat_class}</td>
                  <td className="px-6 py-4 font-medium text-blue-600">
                    {s.price ? `₱${s.price}` : '-'}
                  </td>
                  <td className="px-6 py-4">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                      s.is_available 
                        ? 'bg-green-100 text-green-800' 
                        : 'bg-red-100 text-red-800'
                    }`}>
                      {s.is_available ? 'Available' : 'Booked'}
                    </span>
                  </td>
                </tr>
              )) : (
                <tr>
                  <td colSpan="4" className="px-6 py-8 text-center text-slate-500">
                    No seats found for this flight.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

export default Availability;