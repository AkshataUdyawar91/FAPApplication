import { useState } from 'react';
import { useNavigate } from 'react-router';
import { LogIn } from 'lucide-react';
import { Button } from '../components/ui/button';
import { Card } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { useAuth, UserRole } from '../context/AuthContext';
import { toast } from 'sonner';

export default function Login() {
  const navigate = useNavigate();
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [activeRole, setActiveRole] = useState<UserRole>('agency');

  const handleLogin = async () => {
    if (!email || !password) {
      toast.error('Please enter email and password');
      return;
    }

    setLoading(true);
    const success = await login(email, password, activeRole);
    setLoading(false);

    if (success) {
      toast.success('Login successful!');
      
      // Redirect based on role
      setTimeout(() => {
        switch (activeRole) {
          case 'agency':
            navigate('/agency/dashboard');
            break;
          case 'asm':
            navigate('/asm/review');
            break;
          case 'hq':
            navigate('/hq/analytics');
            break;
          default:
            navigate('/');
        }
      }, 500);
    } else {
      toast.error('Invalid credentials');
    }
  };

  const getRoleLabel = () => {
    switch (activeRole) {
      case 'agency':
        return 'Agency';
      case 'asm':
        return 'ASM';
      case 'hq':
        return 'HQ';
      default:
        return 'User';
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-blue-100 flex items-center justify-center p-6">
      <Card className="w-full max-w-md p-8 border-blue-100 shadow-xl">
        <div className="flex items-center gap-3 mb-8">
          <LogIn className="w-7 h-7 text-blue-600" />
          <h1 className="text-3xl font-bold text-blue-900">Sign In</h1>
        </div>

        {/* Role Tabs */}
        <div className="mb-6">
          <div className="bg-gray-100 rounded-lg p-1.5 grid grid-cols-3 gap-2">
            <button
              onClick={() => setActiveRole('agency')}
              className={`py-2.5 px-4 rounded-md font-medium transition-all ${
                activeRole === 'agency'
                  ? 'bg-white text-blue-900 shadow-sm'
                  : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              Agency
            </button>
            <button
              onClick={() => setActiveRole('asm')}
              className={`py-2.5 px-4 rounded-md font-medium transition-all ${
                activeRole === 'asm'
                  ? 'bg-white text-blue-900 shadow-sm'
                  : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              ASM
            </button>
            <button
              onClick={() => setActiveRole('hq')}
              className={`py-2.5 px-4 rounded-md font-medium transition-all ${
                activeRole === 'hq'
                  ? 'bg-white text-blue-900 shadow-sm'
                  : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              HQ
            </button>
          </div>
        </div>

        {/* Email Field */}
        <div className="mb-4">
          <Label htmlFor="email" className="text-blue-600 font-medium mb-2 block">
            Email Address
          </Label>
          <Input
            id="email"
            type="email"
            placeholder="asm@bajaj.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleLogin()}
            className="border-gray-200 focus:border-blue-500"
          />
        </div>

        {/* Password Field */}
        <div className="mb-6">
          <Label htmlFor="password" className="text-blue-600 font-medium mb-2 block">
            Password
          </Label>
          <Input
            id="password"
            type="password"
            placeholder="Enter your password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleLogin()}
            className="border-gray-200 focus:border-blue-500"
          />
        </div>

        {/* Sign In Button */}
        <Button
          onClick={handleLogin}
          disabled={loading}
          className="w-full bg-blue-600 hover:bg-blue-700 text-white py-6 text-base font-medium"
        >
          {loading ? 'Signing in...' : `Sign In as ${getRoleLabel()}`}
        </Button>
      </Card>
    </div>
  );
}