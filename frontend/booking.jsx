import React, { useState, useEffect } from 'react';
import { User, Plane, CheckCircle, AlertCircle } from 'lucide-react';

const Booking = () => {
  // Data States
  const [flights, setFlights] = useState([]);
  const [seats, setSeats] = useState([]);
  
  // Selection States
  const [selectedFlight, setSelectedFlight] = useState('');
  const [selectedSeats, setSelectedSeats] = useState([]); // Array of seat objects
  const [customerId, setCustomerId] = useState('');
  
  // UI States
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState({ type: '', message: '' });

  // 1. Fetch Flight List on Load
  useEffect(() => {
    fetch('/api/flight')
      .then(res => res.json())
      .then(data => {
        if (Array.isArray(data)) {
          setFlights(data);
        } else {
          console.error("API did not return an array", data);
        }
      })
      .catch(err => console.error("Error loading flights:", err));
  }, []);

  // 2. Fetch Seats when Flight Changes
  useEffect(() => {
    if (!selectedFlight) return;
    
    // Reset selections when flight changes
    setSeats([]);
    setSelectedSeats([]); 
    
    fetch(`/api/flight/${selectedFlight}/seats`)
      .then(res => res.json())
      .then(data => setSeats(data))
      .catch(err => console.error("Error loading seats:", err));
  }, [selectedFlight]);

  // Handle Seat Click
  const toggleSeat = (seat) => {
    if (!seat.is_available) return; // Ignore booked seats

    const isSelected = selectedSeats.find(s => s.seat_number === seat.seat_number);

    if (isSelected) {
      // Remove if already selected
      setSelectedSeats(prev => prev.filter(s => s.seat_number !== seat.seat_number));
    } else {
      // Add to selection
      setSelectedSeats(prev => [...prev, seat]);
    }
  };

  // Calculate Total Price
  const totalPrice = selectedSeats.reduce((sum, seat) => sum + Number(seat.price), 0);

  // Submit Booking
  const handleSubmit = async (e) => {
    e.preventDefault();
    if (selectedSeats.length === 0) {
      setStatus({ type: 'error', message: 'Please select at least one seat.' });
      return;
    }

    setLoading(true);
    setStatus({ type: '', message: '' });

    // Prepare Payload
    const seatNumbers = selectedSeats.map(s => s.seat_number);
    const url = seatNumbers.length === 1 ? "/api/booking/single" : "/api/booking/batch";
    
    const body = {
      customer_id: customerId,
      flight_id: selectedFlight,
      total_price: totalPrice,
      ...(seatNumbers.length === 1 ? { seat_number: seatNumbers[0] } : { seat_numbers: seatNumbers })
    };

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body)
      });
      const data = await response.json();
      
      if (response.ok) {
        setStatus({ type: 'success', message: "Booking Successful!" });
        // Refresh seats to show them as booked
        const updatedSeats = await fetch(`/api/flight/${selectedFlight}/seats`).then(res => res.json());
        setSeats(updatedSeats);
        setSelectedSeats([]); // Clear selection
      } else {
        setStatus({ type: 'error', message: data.error || "Booking failed." });
      }
    } catch (error) {
      setStatus({ type: 'error', message: "Network error." });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col lg:flex-row gap-6 h-[calc(100vh-100px)]">
      
      {/* LEFT PANEL: Inputs & Summary */}
      <div className="w-full lg:w-1/3 flex flex-col gap-6">
        <div className="bg-white p-6 rounded-xl shadow-sm border border-slate-200">
          <h2 className="text-xl font-bold mb-4 text-slate-800 flex items-center gap-2">
            <Plane className="text-blue-600" /> Flight Details
          </h2>
          
          <div className="space-y-4">
            {/* Customer ID */}
            <div>
              <label className="block text-sm font-medium text-slate-600 mb-1">Customer ID</label>
              <div className="relative">
                <User className="absolute left-3 top-2.5 text-slate-400" size={18} />
                <input 
                  type="number" 
                  value={customerId}
                  onChange={(e) => setCustomerId(e.target.value)}
                  placeholder="Enter ID (e.g. 1)"
                  className="w-full pl-10 pr-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                />
              </div>
            </div>

            {/* Flight Dropdown */}
            <div>
              <label className="block text-sm font-medium text-slate-600 mb-1">Select Flight</label>
              <select 
                value={selectedFlight} 
                onChange={(e) => setSelectedFlight(e.target.value)}
                className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none bg-white"
              >
                <option value="">-- Choose Destination --</option>
                {flights.map(f => (
                  <option key={f.flight_id} value={f.flight_id}>
                    {f.flight_number}: {f.origin} ➝ {f.destination}
                  </option>
                ))}
              </select>
            </div>
          </div>
        </div>

        {/* Booking Summary */}
        <div className="bg-white p-6 rounded-xl shadow-sm border border-slate-200 flex-1 flex flex-col">
          <h2 className="text-xl font-bold mb-4 text-slate-800">Booking Summary</h2>
          
          <div className="flex-1">
            {selectedSeats.length > 0 ? (
              <ul className="space-y-2">
                {selectedSeats.map(seat => (
                  <li key={seat.seat_number} className="flex justify-between items-center text-sm p-2 bg-slate-50 rounded">
                    <span className="font-medium">Seat {seat.seat_number} <span className="text-slate-400">({seat.seat_class})</span></span>
                    <span className="font-semibold text-slate-700">₱{seat.price}</span>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-slate-400 text-sm italic">No seats selected.</p>
            )}
          </div>

          <div className="border-t border-slate-100 pt-4 mt-4">
            <div className="flex justify-between items-center mb-4">
              <span className="text-slate-600 font-medium">Total Amount</span>
              <span className="text-2xl font-bold text-blue-600">₱{totalPrice.toLocaleString()}</span>
            </div>

            <button
              onClick={handleSubmit}
              disabled={loading || selectedSeats.length === 0 || !customerId}
              className="w-full bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold py-3 rounded-lg transition shadow-md flex justify-center items-center gap-2"
            >
              {loading ? 'Processing...' : (
                <>
                  <CheckCircle size={20} /> Confirm Booking
                </>
              )}
            </button>

            {status.message && (
              <div className={`mt-4 p-3 rounded-lg text-sm flex items-center gap-2 ${status.type === 'success' ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'}`}>
                {status.type === 'error' && <AlertCircle size={16} />}
                {status.message}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* RIGHT PANEL: Seat Map */}
      <div className="w-full lg:w-2/3 bg-white p-8 rounded-xl shadow-sm border border-slate-200 overflow-y-auto">
        <h2 className="text-xl font-bold mb-6 text-slate-800">Select Seats</h2>
        
        {!selectedFlight ? (
          <div className="h-full flex flex-col items-center justify-center text-slate-400">
            <Plane size={48} className="mb-4 opacity-20" />
            <p>Please select a flight to view seats.</p>
          </div>
        ) : (
          <div>
            <div className="flex gap-6 mb-8 justify-center">
              <div className="flex items-center gap-2 text-sm"><div className="w-6 h-6 rounded bg-slate-100 border border-slate-300"></div> Available</div>
              <div className="flex items-center gap-2 text-sm"><div className="w-6 h-6 rounded bg-blue-600 border border-blue-600"></div> Selected</div>
              <div className="flex items-center gap-2 text-sm"><div className="w-6 h-6 rounded bg-red-100 border border-red-200 opacity-50"></div> Booked</div>
            </div>

            <div className="grid grid-cols-4 gap-4 max-w-md mx-auto">
              {seats.map((seat) => {
                const isSelected = selectedSeats.find(s => s.seat_number === seat.seat_number);
                const isAvailable = seat.is_available;

                return (
                  <button
                    key={seat.seat_number}
                    onClick={() => toggleSeat(seat)}
                    disabled={!isAvailable}
                    className={`
                      relative p-4 rounded-xl border-2 transition-all duration-200 flex flex-col items-center justify-center gap-1
                      ${!isAvailable 
                        ? 'bg-red-50 border-red-100 text-red-300 cursor-not-allowed' 
                        : isSelected
                          ? 'bg-blue-600 border-blue-600 text-white shadow-lg scale-105 z-10'
                          : 'bg-white border-slate-200 hover:border-blue-400 hover:shadow-md text-slate-700'
                      }
                    `}
                  >
                    <span className="font-bold text-lg">{seat.seat_number}</span>
                    <span className={`text-[10px] uppercase tracking-wider ${isSelected ? 'text-blue-100' : 'text-slate-400'}`}>
                      {seat.seat_class}
                    </span>
                    <span className={`text-xs font-semibold ${isSelected ? 'text-white' : 'text-green-600'}`}>
                      ₱{seat.price}
                    </span>
                  </button>
                );
              })}
            </div>
            
            {seats.length === 0 && (
              <p className="text-center text-slate-500 mt-10">No seats found for this flight.</p>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default Booking;