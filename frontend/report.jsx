import React, { useEffect, useState } from 'react';
import { BarChart3, PieChart, Users, TrendingUp, Plane, LayoutDashboard } from 'lucide-react';

const Reports = () => {
  // --- STATES ---
  const [activeTab, setActiveTab] = useState('routes');
  
  const [routes, setRoutes] = useState([]);
  const [seatUtilization, setSeatUtilization] = useState([]);
  const [segmentation, setSegmentation] = useState([]);
  const [occupancy, setOccupancy] = useState([]);
  const [loading, setLoading] = useState(true);

  // --- DATA LOADING ---
  useEffect(() => {
    const loadData = async () => {
      setLoading(true);
      try {
        // Fetch all reports in parallel
        const [routesRes, seatsRes, segRes, occRes] = await Promise.all([
          fetch('/api/reports/routes/top'),               // Matches reportsRoutes.js
          fetch('/api/reports/operations/seat-utilization'), // Matches reportsRoutes.js
          fetch('/api/reports/customers/segments'),       // Matches reportsRoutes.js
          fetch('/api/reports/occupancy')                 // Matches reportsRoutes.js
        ]);

        // 1. TOP ROUTES
        if (routesRes.ok) {
          const data = await routesRes.json();
          // Convert string numbers to actual numbers
          const formatted = data.map(item => ({
            route_code: item.route_code,
            origin: item.origin,
            destination: item.destination,
            total_flights: parseInt(item.total_flights) || 0,
            total_bookings: parseInt(item.total_bookings) || 0,
            total_revenue: parseFloat(item.total_revenue) || 0
          }));
          setRoutes(formatted);
        }

        // 2. SEAT UTILIZATION
        if (seatsRes.ok) {
          const data = await seatsRes.json();
          // Map DB columns (available_seats) to UI expected keys (available)
          const formatted = data.map(item => ({
            seat_class: item.seat_class,
            total_seats: item.total_seats,
            available: item.available_seats, // DB column -> UI key
            booked: item.booked_seats        // DB column -> UI key
          }));
          setSeatUtilization(formatted);
        }

        // 3. CUSTOMER SEGMENTATION
        if (segRes.ok) {
          const data = await segRes.json();
          // Calculate averages based on DB totals
          const formatted = data.map(item => ({
            customer_segment: item.customer_segment,
            customers: item.customer_count,
            // Calculate Avg Bookings per Customer
            avg_bookings: item.customer_count > 0 ? (item.total_bookings / item.customer_count) : 0,
            // Calculate LTV (Total Revenue / Customer Count)
            avg_lifetime_value: item.customer_count > 0 ? (item.total_revenue / item.customer_count) : 0
          }));
          setSegmentation(formatted);
        }

        // 4. FLIGHT OCCUPANCY
        if (occRes.ok) {
          const data = await occRes.json();
          setOccupancy(data);
        }

      } catch (error) {
        console.error("Error loading dashboard data", error);
      } finally {
        setLoading(false);
      }
    };

    loadData();
  }, []);

  // Calculate Max for Graph Scaling
  const maxFlights = Math.max(...routes.map(r => r.total_flights), 1);

  // --- TAB DEFINITIONS ---
  const tabs = [
    { id: 'routes', label: 'Top Routes', icon: TrendingUp },
    { id: 'utilization', label: 'Seat Utilization', icon: PieChart },
    { id: 'segmentation', label: 'Cust. Segmentation', icon: Users },
    { id: 'occupancy', label: 'Flight Occupancy', icon: Plane },
  ];

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6 max-w-5xl mx-auto pb-10">
      
      {/* HEADER */}
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-slate-800 flex items-center gap-2">
          <LayoutDashboard className="text-blue-600" /> Analytics Dashboard
        </h2>
        <div className="bg-green-50 text-green-700 px-3 py-1 rounded-full text-xs font-bold border border-green-200 animate-pulse">
          LIVE WAREHOUSE DATA
        </div>
      </div>

      {/* --- TAB NAVIGATION --- */}
      <div className="bg-slate-100 p-1.5 rounded-xl flex flex-wrap sm:flex-nowrap gap-1 shadow-inner">
        {tabs.map((tab) => {
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`
                flex-1 flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg text-sm font-semibold transition-all duration-200
                ${isActive 
                  ? 'bg-white text-blue-600 shadow-sm ring-1 ring-slate-200 transform scale-[1.02]' 
                  : 'text-slate-500 hover:text-slate-700 hover:bg-slate-200/50'
                }
              `}
            >
              <tab.icon size={16} className={isActive ? 'text-blue-500' : 'text-slate-400'} />
              {tab.label}
            </button>
          );
        })}
      </div>

      {/* --- CONTENT AREA --- */}
      <div className="min-h-[400px]">
        
        {/* REPORT 1: Top Routes (Graph) */}
        {activeTab === 'routes' && (
          <div className="bg-white p-8 rounded-2xl shadow-sm border border-slate-200 animate-in fade-in slide-in-from-bottom-4 duration-300">
            <h3 className="text-lg font-bold text-slate-700 mb-6 flex items-center gap-2">
              <TrendingUp className="text-blue-500" /> Most Frequent Routes
            </h3>
            <div className="space-y-6">
              {routes.length > 0 ? routes.map((r) => (
                <div key={r.route_code || r.origin + r.destination} className="group">
                  <div className="flex justify-between text-sm font-medium mb-2">
                    <span className="text-slate-700 text-base">{r.origin} <span className="text-slate-400 mx-2">➝</span> {r.destination}</span>
                    <span className="bg-slate-100 text-slate-600 px-2 py-0.5 rounded text-xs font-bold">{r.total_flights} Flights</span>
                  </div>
                  <div className="w-full bg-slate-50 rounded-full h-4 overflow-hidden shadow-inner">
                    <div 
                      className="bg-gradient-to-r from-blue-500 to-blue-400 h-4 rounded-full transition-all duration-1000 group-hover:from-blue-600 group-hover:to-blue-500" 
                      style={{ width: `${(r.total_flights / maxFlights) * 100}%` }}
                    ></div>
                  </div>
                </div>
              )) : (
                <p className="text-slate-500 italic">No route data available.</p>
              )}
            </div>
          </div>
        )}

        {/* REPORT 2: Seat Utilization (Table) */}
        {activeTab === 'utilization' && (
          <div className="bg-white p-8 rounded-2xl shadow-sm border border-slate-200 animate-in fade-in slide-in-from-bottom-4 duration-300">
            <h3 className="text-lg font-bold text-slate-700 mb-6 flex items-center gap-2">
              <PieChart className="text-green-600" /> Seat Class Usage
            </h3>
            <div className="overflow-hidden rounded-xl border border-slate-200">
              <table className="w-full text-left text-sm">
                <thead className="bg-slate-50 text-slate-500 font-semibold uppercase tracking-wider">
                  <tr>
                    <th className="px-6 py-4">Class</th>
                    <th className="px-6 py-4 text-right">Total Capacity</th>
                    <th className="px-6 py-4 text-right">Available</th>
                    <th className="px-6 py-4 text-right">Booked</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {seatUtilization.map((row, i) => (
                    <tr key={i} className="hover:bg-slate-50 transition-colors">
                      <td className="px-6 py-4 font-bold text-slate-700">{row.seat_class}</td>
                      <td className="px-6 py-4 text-right text-slate-600">{row.total_seats}</td>
                      <td className="px-6 py-4 text-right text-green-600 font-bold">{row.available}</td>
                      <td className="px-6 py-4 text-right text-blue-600 font-bold">{row.booked}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* REPORT 3: Customer Segmentation (Table) */}
        {activeTab === 'segmentation' && (
          <div className="bg-white p-8 rounded-2xl shadow-sm border border-slate-200 animate-in fade-in slide-in-from-bottom-4 duration-300">
            <h3 className="text-lg font-bold text-slate-700 mb-6 flex items-center gap-2">
              <Users className="text-purple-600" /> Customer Insights
            </h3>
            <div className="overflow-hidden rounded-xl border border-slate-200">
              <table className="w-full text-left text-sm">
                <thead className="bg-slate-50 text-slate-500 font-semibold uppercase tracking-wider">
                  <tr>
                    <th className="px-6 py-4">Segment</th>
                    <th className="px-6 py-4">Total Customers</th>
                    <th className="px-6 py-4">Avg. Bookings</th>
                    <th className="px-6 py-4">Avg. Lifetime Value</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {segmentation.map((seg, i) => (
                    <tr key={i} className="hover:bg-slate-50 transition-colors">
                      <td className="px-6 py-4">
                        <span className="bg-purple-100 text-purple-700 px-3 py-1 rounded-full text-xs font-bold border border-purple-200">
                          {seg.customer_segment}
                        </span>
                      </td>
                      <td className="px-6 py-4 text-slate-600 font-medium">{seg.customers}</td>
                      <td className="px-6 py-4 text-slate-600">{Number(seg.avg_bookings).toFixed(2)}</td>
                      <td className="px-6 py-4 text-slate-800 font-bold">₱{Number(seg.avg_lifetime_value).toLocaleString()}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* REPORT 4: Flight Occupancy */}
        {activeTab === 'occupancy' && (
          <div className="bg-white p-8 rounded-2xl shadow-sm border border-slate-200 animate-in fade-in slide-in-from-bottom-4 duration-300">
             <h3 className="text-lg font-bold text-slate-700 mb-6 flex items-center gap-2">
              <Plane className="text-slate-600" /> Flight Occupancy
            </h3>
            <div className="overflow-hidden rounded-xl border border-slate-200">
              <table className="w-full text-left text-sm">
                <thead className="bg-slate-50 text-slate-500 font-semibold uppercase tracking-wider">
                  <tr>
                    <th className="px-6 py-4">Flight</th>
                    <th className="px-6 py-4">Booked</th>
                    <th className="px-6 py-4">Available</th>
                    <th className="px-6 py-4 w-1/3">Occupancy Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {occupancy.length > 0 ? (
                    occupancy.map((r, idx) => {
                      const total = parseInt(r.booked) + parseInt(r.available);
                      const percentage = total > 0 ? Math.round((parseInt(r.booked) / total) * 100) : 0;
                      
                      return (
                        <tr key={idx} className="hover:bg-slate-50 transition-colors">
                          <td className="px-6 py-4 font-bold text-slate-900">{r.flight}</td>
                          <td className="px-6 py-4 text-slate-600">{r.booked}</td>
                          <td className="px-6 py-4 text-slate-600">{r.available}</td>
                          <td className="px-6 py-4">
                            <div className="flex items-center gap-3">
                              <div className="flex-1 bg-slate-200 rounded-full h-2.5 overflow-hidden">
                                <div 
                                  className={`h-full rounded-full ${percentage > 80 ? 'bg-red-500' : 'bg-blue-600'}`}
                                  style={{ width: `${percentage}%` }}
                                ></div>
                              </div>
                              <span className="text-xs font-bold text-slate-700 min-w-[3rem]">{percentage}%</span>
                            </div>
                          </td>
                        </tr>
                      );
                    })
                  ) : (
                    <tr>
                      <td colSpan="4" className="px-6 py-12 text-center text-slate-400 italic">
                        No active flights found.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}

      </div>
    </div>
  );
};

export default Reports;