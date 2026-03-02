import { useState } from 'react';
import { Link } from 'react-router';
import { ChevronLeft, Search, Filter, CheckCircle, XCircle, AlertTriangle, Brain, TrendingUp, TrendingDown, Clock, LogOut } from 'lucide-react';
import { Card } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Badge } from '../components/ui/badge';
import { Button } from '../components/ui/button';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';
import { mockDocuments } from '../data/mockData';
import { motion } from 'motion/react';
import { useAuth } from '../context/AuthContext';
import { useNavigate } from 'react-router';

export default function ASMReview() {
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [sortBy, setSortBy] = useState('date');

  const handleLogout = () => {
    logout();
    navigate('/');
  };

  const reviewDocuments = mockDocuments.filter(
    (doc) => doc.status === 'asm-review' || doc.status === 'approved' || doc.status === 'rejected'
  );

  const filteredDocuments = reviewDocuments.filter((doc) => {
    const matchesSearch = doc.agencyName.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         doc.id.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesStatus = statusFilter === 'all' || doc.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'asm-review':
        return <Badge className="bg-yellow-100 text-yellow-800 hover:bg-yellow-100">Pending Review</Badge>;
      case 'approved':
        return <Badge className="bg-green-100 text-green-800 hover:bg-green-100">Approved</Badge>;
      case 'rejected':
        return <Badge className="bg-red-100 text-red-800 hover:bg-red-100">Rejected</Badge>;
      default:
        return <Badge>{status}</Badge>;
    }
  };

  const getConfidenceBadge = (confidence?: number) => {
    if (!confidence) return null;
    
    if (confidence >= 80) {
      return (
        <div className="flex items-center gap-1 text-green-600">
          <TrendingUp className="w-4 h-4" />
          <span className="text-sm font-semibold">{confidence}%</span>
        </div>
      );
    } else if (confidence >= 60) {
      return (
        <div className="flex items-center gap-1 text-yellow-600">
          <AlertTriangle className="w-4 h-4" />
          <span className="text-sm font-semibold">{confidence}%</span>
        </div>
      );
    } else {
      return (
        <div className="flex items-center gap-1 text-red-600">
          <TrendingDown className="w-4 h-4" />
          <span className="text-sm font-semibold">{confidence}%</span>
        </div>
      );
    }
  };

  const getRecommendationIcon = (recommendation?: string) => {
    switch (recommendation) {
      case 'approve':
        return <CheckCircle className="w-5 h-5 text-green-600" />;
      case 'reject':
        return <XCircle className="w-5 h-5 text-red-600" />;
      case 'review':
        return <AlertTriangle className="w-5 h-5 text-yellow-600" />;
      default:
        return null;
    }
  };

  const pendingCount = reviewDocuments.filter((d) => d.status === 'asm-review').length;
  const approvedCount = reviewDocuments.filter((d) => d.status === 'approved').length;
  const rejectedCount = reviewDocuments.filter((d) => d.status === 'rejected').length;

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-white">
      {/* Header */}
      <header className="bg-gradient-to-r from-blue-900 to-blue-800 shadow-lg">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <Link to="/" className="flex items-center gap-2 text-blue-100 hover:text-white transition-colors">
              <ChevronLeft className="w-5 h-5" />
              <span className="font-medium">Back to Login</span>
            </Link>
            <div className="flex items-center gap-4">
              <div className="text-right">
                <p className="text-xs text-blue-200">Logged in as</p>
                <p className="font-semibold text-white">{user?.name}</p>
              </div>
              <Button
                onClick={handleLogout}
                variant="outline"
                size="sm"
                className="border-blue-300 text-white hover:bg-blue-700 hover:text-white"
              >
                <LogOut className="w-4 h-4 mr-2" />
                Logout
              </Button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-6 py-8">
        {/* Stats Overview */}
        <div className="grid md:grid-cols-3 gap-6 mb-8">
          <Card className="p-6 border-blue-100">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-blue-600 mb-1">Pending Review</p>
                <p className="text-3xl font-bold text-blue-900">{pendingCount}</p>
              </div>
              <Clock className="w-10 h-10 text-yellow-500" />
            </div>
          </Card>

          <Card className="p-6 border-blue-100">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-blue-600 mb-1">Approved</p>
                <p className="text-3xl font-bold text-green-600">{approvedCount}</p>
              </div>
              <CheckCircle className="w-10 h-10 text-green-500" />
            </div>
          </Card>

          <Card className="p-6 border-blue-100">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-blue-600 mb-1">Rejected</p>
                <p className="text-3xl font-bold text-red-600">{rejectedCount}</p>
              </div>
              <XCircle className="w-10 h-10 text-red-500" />
            </div>
          </Card>
        </div>

        {/* Filters */}
        <Card className="p-6 mb-6 border-blue-100">
          <div className="flex flex-col md:flex-row gap-4">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
              <Input
                placeholder="Search by agency name or document ID..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10 border-blue-200"
              />
            </div>
            <Select value={statusFilter} onValueChange={setStatusFilter}>
              <SelectTrigger className="w-full md:w-48 border-blue-200">
                <SelectValue placeholder="Filter by status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Status</SelectItem>
                <SelectItem value="asm-review">Pending Review</SelectItem>
                <SelectItem value="approved">Approved</SelectItem>
                <SelectItem value="rejected">Rejected</SelectItem>
              </SelectContent>
            </Select>
            <Select value={sortBy} onValueChange={setSortBy}>
              <SelectTrigger className="w-full md:w-48 border-blue-200">
                <SelectValue placeholder="Sort by" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="date">Date</SelectItem>
                <SelectItem value="amount">Amount</SelectItem>
                <SelectItem value="confidence">Confidence</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </Card>

        {/* Documents List */}
        <div className="space-y-4">
          {filteredDocuments.map((doc, index) => (
            <motion.div
              key={doc.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.1 }}
            >
              <Card className="p-6 hover:shadow-lg transition-shadow border-blue-100">
                <div className="flex flex-col md:flex-row md:items-center gap-4">
                  {/* AI Recommendation Icon */}
                  <div className="flex-shrink-0">
                    <div className="w-12 h-12 bg-blue-50 rounded-full flex items-center justify-center">
                      {getRecommendationIcon(doc.aiAnalysis?.recommendation)}
                    </div>
                  </div>

                  {/* Document Info */}
                  <div className="flex-1">
                    <div className="flex items-start justify-between mb-2">
                      <div>
                        <h3 className="font-bold text-blue-900 text-lg mb-1">
                          {doc.agencyName}
                        </h3>
                        <p className="text-sm text-blue-600">Document ID: {doc.id}</p>
                      </div>
                      {getStatusBadge(doc.status)}
                    </div>

                    <div className="grid md:grid-cols-4 gap-4 mt-4">
                      <div>
                        <p className="text-xs text-blue-600 mb-1">Amount</p>
                        <p className="font-semibold text-blue-900">
                          ₹{doc.amount.toLocaleString('en-IN')}
                        </p>
                      </div>
                      <div>
                        <p className="text-xs text-blue-600 mb-1">Submitted</p>
                        <p className="font-semibold text-blue-900">
                          {new Date(doc.submittedDate).toLocaleDateString('en-IN')}
                        </p>
                      </div>
                      <div>
                        <p className="text-xs text-blue-600 mb-1">AI Confidence</p>
                        <div className="font-semibold">
                          {getConfidenceBadge(doc.aiAnalysis?.confidence)}
                        </div>
                      </div>
                      <div>
                        <p className="text-xs text-blue-600 mb-1">AI Recommendation</p>
                        <p className="font-semibold capitalize text-blue-900">
                          {doc.aiAnalysis?.recommendation}
                        </p>
                      </div>
                    </div>

                    {/* Flags */}
                    {doc.aiAnalysis?.flags && doc.aiAnalysis.flags.length > 0 && (
                      <div className="mt-4 flex flex-wrap gap-2">
                        {doc.aiAnalysis.flags.map((flag) => (
                          <Badge key={flag} variant="outline" className="text-orange-700 border-orange-300">
                            {flag}
                          </Badge>
                        ))}
                      </div>
                    )}

                    {/* Decision Info */}
                    {doc.asmDecision && (
                      <div className="mt-4 p-3 bg-blue-50 rounded-lg">
                        <div className="flex items-start gap-2">
                          {doc.asmDecision.action === 'approved' ? (
                            <CheckCircle className="w-5 h-5 text-green-600 mt-0.5" />
                          ) : (
                            <XCircle className="w-5 h-5 text-red-600 mt-0.5" />
                          )}
                          <div>
                            <p className="font-semibold text-blue-900 mb-1">
                              {doc.asmDecision.officer}
                            </p>
                            <p className="text-sm text-blue-700">{doc.asmDecision.comments}</p>
                          </div>
                        </div>
                      </div>
                    )}
                  </div>

                  {/* Action Button */}
                  <div className="flex-shrink-0">
                    <Link to={`/asm/document/${doc.id}`}>
                      <Button className="bg-blue-600 hover:bg-blue-700 text-white w-full md:w-auto">
                        {doc.status === 'asm-review' ? 'Review' : 'View Details'}
                      </Button>
                    </Link>
                  </div>
                </div>
              </Card>
            </motion.div>
          ))}
        </div>

        {filteredDocuments.length === 0 && (
          <Card className="p-12 text-center border-blue-100">
            <p className="text-blue-600">No documents found matching your criteria.</p>
          </Card>
        )}
      </div>
    </div>
  );
}