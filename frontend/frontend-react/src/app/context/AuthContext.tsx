import { createContext, useContext, useState, ReactNode } from 'react';

export type UserRole = 'agency' | 'asm' | 'hq' | null;

interface User {
  id: string;
  name: string;
  role: UserRole;
  email: string;
}

interface AuthContextType {
  user: User | null;
  login: (email: string, password: string, role: UserRole) => Promise<boolean>;
  logout: () => void;
  isAuthenticated: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

// Mock users for different roles
const mockUsers = {
  agency: {
    id: 'agency-001',
    name: 'Creative Marketing Solutions',
    role: 'agency' as UserRole,
    email: 'agency@example.com',
  },
  asm: {
    id: 'asm-001',
    name: 'Rajesh Kumar',
    role: 'asm' as UserRole,
    email: 'asm@bajaj.com',
  },
  hq: {
    id: 'hq-001',
    name: 'Analytics Manager',
    role: 'hq' as UserRole,
    email: 'hq@bajaj.com',
  },
};

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);

  const login = async (email: string, password: string, role: UserRole): Promise<boolean> => {
    // Simulate API call
    await new Promise((resolve) => setTimeout(resolve, 1000));

    // Simple mock authentication
    if (role && mockUsers[role]) {
      setUser(mockUsers[role]);
      localStorage.setItem('user', JSON.stringify(mockUsers[role]));
      return true;
    }

    return false;
  };

  const logout = () => {
    setUser(null);
    localStorage.removeItem('user');
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        login,
        logout,
        isAuthenticated: !!user,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
