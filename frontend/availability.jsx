import React, { useState } from 'react';
import { Search } from 'lucide-react';

const Availability = () => {
  const [flightId, setFlightId] = useState('');
  const [seats, setSeats] = useState([]);
  const [hasSearched, setHasSearched] = useState(false);

  const checkSeats = async () => {
    if (!flightId) return;
    try {
      const response = await fetch(`/api/flight/${flightId}/seats`);
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
          <label className="block text-sm font-medium text-slate-600 mb-2">Check Flight Availability</label>
          <input
            type="number"
            value={flightId}
            onChange={(e) => setFlightId(e.target.value)}
            placeholder="Enter Flight ID (e.g. 1)"
            className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
          />
        </div>
        <button 
          onClick={checkSeats}
          className="bg-slate-800 text-white px-6 py-2 rounded-lg hover:bg-slate-900 transition flex items-center gap-2"
        >
          <Search size={18} /> Check
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
                    {/* Display Price if it exists */}
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
                  <td colSpan="4" className="px-6 py-8 text-center text-slate-500">No seats found for this flight ID.</td>
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