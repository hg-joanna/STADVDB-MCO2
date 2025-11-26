import React, { useEffect, useState } from 'react';
import { BarChart3 } from 'lucide-react';

const Reports = () => {
  const [reports, setReports] = useState([]);

  useEffect(() => {
    const fetchReports = async () => {
      try {
        const response = await fetch('/api/report');
        const data = await response.json();
        setReports(data);
      } catch (error) {
        console.error("Failed to load reports");
      }
    };
    fetchReports();
  }, []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-slate-800">Flight Occupancy Reports</h2>
        <div className="bg-blue-50 text-blue-700 px-4 py-2 rounded-lg text-sm font-medium flex items-center gap-2">
          <BarChart3 size={16} /> Live Data
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
        <table className="w-full text-left">
          <thead className="bg-slate-50 border-b border-slate-200">
            <tr>
              <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase">Flight</th>
              <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase">Booked Seats</th>
              <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase">Available Seats</th>
              <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase">Occupancy</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {reports.map((r, idx) => {
              const total = r.booked + r.available;
              const percentage = total > 0 ? Math.round((r.booked / total) * 100) : 0;
              
              return (
                <tr key={idx} className="hover:bg-slate-50">
                  <td className="px-6 py-4 font-medium text-slate-900">{r.flight}</td>
                  <td className="px-6 py-4 text-slate-600">{r.booked}</td>
                  <td className="px-6 py-4 text-slate-600">{r.available}</td>
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-3">
                      <div className="w-full max-w-[100px] bg-slate-200 rounded-full h-2">
                        <div 
                          className="bg-blue-600 h-2 rounded-full" 
                          style={{ width: `${percentage}%` }}
                        ></div>
                      </div>
                      <span className="text-xs font-medium text-slate-600">{percentage}%</span>
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default Reports;