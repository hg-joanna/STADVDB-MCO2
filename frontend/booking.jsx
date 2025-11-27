import React, { useState, useEffect } from 'react';
import { User, Plane, CheckCircle, AlertCircle, Armchair, CreditCard } from 'lucide-react';

const Booking = () => {
  // Data States
  const [flights, setFlights] = useState([]);
  const [seats, setSeats] = useState([]);
  
  // Selection States
  const [selectedFlight, setSelectedFlight] = useState('');
  const [selectedSeats, setSelectedSeats] = useState([]); // Array of seat objects
  
  // User Input States
  const [customerId, setCustomerId] = useState('');
  const [customerName, setCustomerName] = useState('');

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

  // Toggle Seat Selection
  const toggleSeat = (seat) => {
    if (!seat.is_available) return;

    const isSelected = selectedSeats.some(s => s.seat_number === seat.seat_number);
    
    if (isSelected) {
      setSelectedSeats(prev => prev.filter(s => s.seat_number !== seat.seat_number));
    } else {
      setSelectedSeats(prev => [...prev, seat]);
    }
  };

  // Handle Booking Submission
  const handleBooking = async () => {
    // 1. Validation
    if (!customerId || !customerName) {
      setStatus({ type: 'error', message: 'Please enter both Customer Name and ID.' });
      return;
    }
    if (selectedSeats.length === 0) {
      setStatus({ type: 'error', message: 'Please select at least one seat.' });
      return;
    }

    setLoading(true);
    setStatus({ type: '', message: '' });

    // 2. Prepare Payload
    const total_price = selectedSeats.reduce((sum, seat) => sum + (parseFloat(seat.price) || 0), 0);
    
    // Determine if Single or Batch
    const isBatch = selectedSeats.length > 1;
    const endpoint = isBatch ? '/api/booking/batch' : '/api/booking/single';
    
    const payload = isBatch 
      ? {
          customer_id: parseInt(customerId),
          flight_id: selectedFlight,
          seat_numbers: selectedSeats.map(s => s.seat_number), // Array of numbers
          total_price: total_price
        }
      : {
          customer_id: parseInt(customerId),
          flight_id: selectedFlight,
          seat_number: selectedSeats[0].seat_number,
          total_price: total_price
        };

    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || 'Booking failed');
      }

      // Success
      setStatus({ type: 'success', message: 'Booking Successful!' });
      setSelectedSeats([]); // Clear selection
      
      // Refresh seats to show them as taken
      const seatRes = await fetch(`/api/flight/${selectedFlight}/seats`);
      const seatData = await seatRes.json();
      setSeats(seatData);

    } catch (error) {
      setStatus({ type: 'error', message: error.message });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-6xl mx-auto space-y-8">
      
      {/* Header */}
      <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200">
        <h1 className="text-2xl font-bold text-slate-800 flex items-center gap-2">
          <Plane className="text-blue-600" /> 
          Flight Booking
        </h1>
        <p className="text-slate-500 mt-1">Select a flight, enter your details, and choose your seats.</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        
        {/* LEFT COLUMN: Controls & Form */}
        <div className="space-y-6">
          
          {/* 1. Select Flight */}
          <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200">
            <label className="block text-sm font-medium text-slate-700 mb-2">Select Flight</label>
            <select 
              value={selectedFlight}
              onChange={(e) => setSelectedFlight(e.target.value)}
              className="w-full p-3 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-blue-500 outline-none"
            >
              <option value="">-- Choose Destination --</option>
              {flights.map(f => (
                <option key={f.flight_id} value={f.flight_id}>
                  {f.flight_number}: {f.origin} ➝ {f.destination}
                </option>
              ))}
            </select>
          </div>

          {/* 2. Customer Details */}
          <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200 space-y-4">
             <div className="flex items-center gap-2 text-slate-800 font-semibold border-b border-slate-100 pb-2">
                <User size={20} className="text-blue-500" /> Passenger Details
             </div>
             
             <div>
                <label className="block text-xs font-semibold text-slate-500 uppercase mb-1">Customer Name</label>
                <input 
                  type="text"
                  value={customerName}
                  onChange={(e) => setCustomerName(e.target.value)}
                  placeholder="e.g. John Doe"
                  className="w-full p-3 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-blue-500 outline-none"
                />
             </div>

             <div>
                <label className="block text-xs font-semibold text-slate-500 uppercase mb-1">Customer ID</label>
                <input 
                  type="number"
                  value={customerId}
                  onChange={(e) => setCustomerId(e.target.value)}
                  placeholder="e.g. 5"
                  className="w-full p-3 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-blue-500 outline-none"
                />
                <p className="text-xs text-slate-400 mt-1">Must match a valid ID (1-100) in database.</p>
             </div>
          </div>

          {/* 3. Booking Summary */}
          {selectedSeats.length > 0 && (
            <div className="bg-blue-600 text-white p-6 rounded-2xl shadow-lg">
              <h3 className="font-semibold flex items-center gap-2 mb-4">
                <CreditCard size={20} /> Summary
              </h3>
              <div className="space-y-2 text-blue-100 text-sm mb-6">
                <div className="flex justify-between">
                   <span>Seats:</span>
                   <span className="font-medium text-white">{selectedSeats.length}</span>
                </div>
                <div className="flex justify-between">
                   <span>Seat Numbers:</span>
                   <span className="font-medium text-white">{selectedSeats.map(s => s.seat_number).join(', ')}</span>
                </div>
                <div className="h-px bg-blue-500/50 my-2"></div>
                <div className="flex justify-between text-lg font-bold text-white">
                   <span>Total:</span>
                   <span>₱{selectedSeats.reduce((sum, s) => sum + (parseFloat(s.price) || 0), 0).toLocaleString()}</span>
                </div>
              </div>

              <button 
                onClick={handleBooking}
                disabled={loading}
                className="w-full py-3 bg-white text-blue-700 font-bold rounded-xl hover:bg-blue-50 transition shadow-sm disabled:opacity-50"
              >
                {loading ? 'Processing...' : 'Confirm Booking'}
              </button>
            </div>
          )}

          {/* Status Messages */}
          {status.message && (
            <div className={`p-4 rounded-xl flex items-start gap-3 ${
              status.type === 'error' ? 'bg-red-50 text-red-700' : 'bg-green-50 text-green-700'
            }`}>
              {status.type === 'error' ? <AlertCircle size={20} /> : <CheckCircle size={20} />}
              <p className="text-sm font-medium">{status.message}</p>
            </div>
          )}

        </div>

        {/* RIGHT COLUMN: Seat Map */}
        <div className="lg:col-span-2">
          <div className="bg-white p-8 rounded-2xl shadow-sm border border-slate-200 min-h-[500px]">
            <h2 className="text-lg font-semibold text-slate-800 mb-6 flex items-center gap-2">
              <Armchair className="text-slate-400" /> Select Seats
            </h2>

            {!selectedFlight ? (
              <div className="h-full flex flex-col items-center justify-center text-slate-400 opacity-60 mt-20">
                <Plane size={64} className="mb-4" />
                <p>Please select a flight to view the seat map.</p>
              </div>
            ) : (
              <div className="grid grid-cols-4 sm:grid-cols-6 gap-4">
                {seats.map((seat) => {
                  const isSelected = selectedSeats.some(s => s.seat_number === seat.seat_number);
                  const isAvailable = seat.is_available;

                  return (
                    <button
                      key={seat.seat_id}
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
            )}
            
            {selectedFlight && seats.length === 0 && (
              <p className="text-center text-slate-500 mt-10">No seats found for this flight.</p>
            )}
          </div>
        </div>

      </div>
    </div>
  );
};

export default Booking;