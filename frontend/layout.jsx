import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Plane, CalendarCheck, FileBarChart, Search } from 'lucide-react';

const Layout = ({ children }) => {
  const location = useLocation();

  const navItems = [
    { name: 'Check Availability', path: '/availability', icon: <Search size={20} /> },
    { name: 'Book Flight', path: '/', icon: <CalendarCheck size={20} /> },
    { name: 'Reports', path: '/reports', icon: <FileBarChart size={20} /> },
  ];

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col md:flex-row font-sans text-slate-900">
      {/* Sidebar Navigation */}
      <aside className="w-full md:w-64 bg-slate-900 text-white flex-shrink-0">
        <div className="p-6 flex items-center space-x-3 border-b border-slate-700">
          <Plane className="text-blue-400" />
          <span className="text-xl font-bold tracking-tight">STADVDB</span>
        </div>
        <nav className="p-4 space-y-2">
          {navItems.map((item) => (
            <Link
              key={item.path}
              to={item.path}
              className={`flex items-center space-x-3 px-4 py-3 rounded-lg transition-all duration-200 ${
                location.pathname === item.path
                  ? 'bg-blue-600 text-white shadow-lg'
                  : 'text-slate-400 hover:bg-slate-800 hover:text-white'
              }`}
            >
              {item.icon}
              <span>{item.name}</span>
            </Link>
          ))}
        </nav>
      </aside>

      {/* Main Content Area */}
      <main className="flex-1 p-6 md:p-10 overflow-y-auto">
        <div className="max-w-4xl mx-auto">
          {children}
        </div>
      </main>
    </div>
  );
};

export default Layout;