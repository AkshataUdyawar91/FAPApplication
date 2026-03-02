import { Link, useLocation } from 'react-router';
import { FileText, Plus, LogOut } from 'lucide-react';
import { Button } from './ui/button';
import { useAuth } from '../context/AuthContext';
import { useNavigate } from 'react-router';

export function AgencySidebar() {
  const location = useLocation();
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/');
  };

  const isActive = (path: string) => {
    return location.pathname === path;
  };

  return (
    <aside className="w-64 bg-blue-900 flex flex-col h-screen sticky top-0">
      {/* Logo */}
      <div className="p-6 border-b border-blue-800">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-white rounded-lg flex items-center justify-center">
            <FileText className="w-6 h-6 text-blue-900" />
          </div>
          <div>
            <h2 className="font-bold text-white">Bajaj Auto</h2>
            <p className="text-xs text-blue-200">Agency Portal</p>
          </div>
        </div>
      </div>

      {/* User Info */}
      <div className="px-6 py-4 border-b border-blue-800">
        <p className="text-xs text-blue-300 mb-1">Logged in as</p>
        <p className="font-semibold text-white">{user?.name}</p>
      </div>

      {/* Navigation */}
      <nav className="flex-1 p-4">
        <div className="space-y-2">
          <Link
            to="/agency/dashboard"
            className={`flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
              isActive('/agency/dashboard')
                ? 'bg-blue-800 text-white font-medium'
                : 'text-blue-100 hover:bg-blue-800 hover:text-white'
            }`}
          >
            <FileText className="w-5 h-5" />
            <span>All Requests</span>
          </Link>

          <Link
            to="/agency/upload"
            className={`flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
              isActive('/agency/upload')
                ? 'bg-blue-800 text-white font-medium'
                : 'text-blue-100 hover:bg-blue-800 hover:text-white'
            }`}
          >
            <Plus className="w-5 h-5" />
            <span>Create Request</span>
          </Link>
        </div>
      </nav>

      {/* Logout Button */}
      <div className="p-4 border-t border-blue-800">
        <Button
          onClick={handleLogout}
          variant="outline"
          className="w-full justify-start border-blue-700 text-white hover:bg-blue-800 hover:text-white"
        >
          <LogOut className="w-4 h-4 mr-2" />
          Logout
        </Button>
      </div>
    </aside>
  );
}