import { useState } from 'react';
import { Link } from 'react-router';
import { Plus, Search, Filter, Clock, CheckCircle, XCircle, AlertTriangle, Eye, FileText } from 'lucide-react';
import { Card } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Badge } from '../components/ui/badge';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';
import { AgencySidebar } from '../components/AgencySidebar';
import { motion } from 'motion/react';

interface Request {
  id: string;
  submittedDate: string;
  status: 'pending' | 'approved' | 'rejected' | 'under_review';
  totalAmount: number;
  documents: {
    po: boolean;
    invoice: boolean;
    photos: boolean;
    costSummary: boolean;
  };
  aiConfidence?: number;
  reviewedBy?: string;
  reviewDate?: string;
  remarks?: string;
}

// Mock data for agency requests
const mockRequests: Request[] = [
  {
    id: 'REQ-2024-001',
    submittedDate: '2024-02-28',
    status: 'approved',
    totalAmount: 125000,
    documents: {
      po: true,
      invoice: true,
      photos: true,
      costSummary: true,
    },
    aiConfidence: 95,
    reviewedBy: 'Rajesh Kumar (ASM)',
    reviewDate: '2024-03-01',
    remarks: 'All documents verified and approved',
  },
  {
    id: 'REQ-2024-002',
    submittedDate: '2024-03-01',
    status: 'under_review',
    totalAmount: 87500,
    documents: {
      po: true,
      invoice: true,
      photos: true,
      costSummary: true,
    },
    aiConfidence: 88,
  },
  {
    id: 'REQ-2024-003',
    submittedDate: '2024-02-25',
    status: 'rejected',
    totalAmount: 45000,
    documents: {
      po: true,
      invoice: true,
      photos: false,
      costSummary: true,
    },
    aiConfidence: 62,
    reviewedBy: 'Priya Sharma (ASM)',
    reviewDate: '2024-02-26',
    remarks: 'Event photos missing. Please resubmit with complete documentation.',
  },
  {
    id: 'REQ-2024-004',
    submittedDate: '2024-02-20',
    status: 'approved',
    totalAmount: 156000,
    documents: {
      po: true,
      invoice: true,
      photos: true,
      costSummary: true,
    },
    aiConfidence: 92,
    reviewedBy: 'Rajesh Kumar (ASM)',
    reviewDate: '2024-02-22',
    remarks: 'Approved for payment',
  },
  {
    id: 'REQ-2024-005',
    submittedDate: '2024-03-02',
    status: 'pending',
    totalAmount: 98000,
    documents: {
      po: true,
      invoice: true,
      photos: true,
      costSummary: true,
    },
    aiConfidence: 85,
  },
];

export default function AgencyDashboard() {
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [requests, setRequests] = useState(mockRequests);

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'approved':
        return <CheckCircle className="w-5 h-5 text-green-600" />;
      case 'rejected':
        return <XCircle className="w-5 h-5 text-red-600" />;
      case 'under_review':
        return <Eye className="w-5 h-5 text-blue-600" />;
      default:
        return <Clock className="w-5 h-5 text-yellow-600" />;
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'approved':
        return <Badge className="bg-green-100 text-green-700">Approved</Badge>;
      case 'rejected':
        return <Badge className="bg-red-100 text-red-700">Rejected</Badge>;
      case 'under_review':
        return <Badge className="bg-blue-100 text-blue-700">Under Review</Badge>;
      default:
        return <Badge className="bg-yellow-100 text-yellow-700">Pending</Badge>;
    }
  };

  const filteredRequests = requests.filter((req) => {
    const matchesSearch = req.id.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesStatus = statusFilter === 'all' || req.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  // Calculate stats
  const stats = {
    total: requests.length,
    pending: requests.filter((r) => r.status === 'pending').length,
    approved: requests.filter((r) => r.status === 'approved').length,
    rejected: requests.filter((r) => r.status === 'rejected').length,
    underReview: requests.filter((r) => r.status === 'under_review').length,
  };

  return (
    <div className="flex min-h-screen bg-gray-50">
      <AgencySidebar />

      {/* Main Content */}
      <div className="flex-1 overflow-auto">
        {/* Header */}
        <header className="bg-white border-b border-gray-200 sticky top-0 z-10">
          <div className="px-8 py-6">
            <div className="flex items-center justify-between">
              <div>
                <h1 className="text-2xl font-bold text-gray-900">All Requests</h1>
                <p className="text-sm text-gray-500 mt-1">View and track all your reimbursement requests</p>
              </div>
              <Link to="/agency/upload">
                <Button className="bg-blue-600 hover:bg-blue-700 text-white">
                  <Plus className="w-4 h-4 mr-2" />
                  Create New Request
                </Button>
              </Link>
            </div>
          </div>
        </header>

        <div className="p-8">
          {/* Stats Cards */}
          <div className="grid grid-cols-1 md:grid-cols-5 gap-4 mb-8">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1 }}
            >
              <Card className="p-4 border-gray-200">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-gray-500">Total Requests</p>
                    <p className="text-2xl font-bold text-gray-900 mt-1">{stats.total}</p>
                  </div>
                  <FileText className="w-8 h-8 text-gray-400" />
                </div>
              </Card>
            </motion.div>

            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 }}
            >
              <Card className="p-4 border-yellow-200 bg-yellow-50">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-yellow-700">Pending</p>
                    <p className="text-2xl font-bold text-yellow-900 mt-1">{stats.pending}</p>
                  </div>
                  <Clock className="w-8 h-8 text-yellow-600" />
                </div>
              </Card>
            </motion.div>

            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
            >
              <Card className="p-4 border-blue-200 bg-blue-50">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-blue-700">Under Review</p>
                    <p className="text-2xl font-bold text-blue-900 mt-1">{stats.underReview}</p>
                  </div>
                  <Eye className="w-8 h-8 text-blue-600" />
                </div>
              </Card>
            </motion.div>

            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4 }}
            >
              <Card className="p-4 border-green-200 bg-green-50">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-green-700">Approved</p>
                    <p className="text-2xl font-bold text-green-900 mt-1">{stats.approved}</p>
                  </div>
                  <CheckCircle className="w-8 h-8 text-green-600" />
                </div>
              </Card>
            </motion.div>

            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.5 }}
            >
              <Card className="p-4 border-red-200 bg-red-50">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-red-700">Rejected</p>
                    <p className="text-2xl font-bold text-red-900 mt-1">{stats.rejected}</p>
                  </div>
                  <XCircle className="w-8 h-8 text-red-600" />
                </div>
              </Card>
            </motion.div>
          </div>

          {/* Filters */}
          <Card className="p-4 mb-6 border-gray-200">
            <div className="flex flex-col sm:flex-row gap-4">
              <div className="flex-1 relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
                <Input
                  placeholder="Search by request ID..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10 border-gray-200"
                />
              </div>
              <Select value={statusFilter} onValueChange={setStatusFilter}>
                <SelectTrigger className="w-full sm:w-[200px] border-gray-200">
                  <Filter className="w-4 h-4 mr-2" />
                  <SelectValue placeholder="Filter by status" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Statuses</SelectItem>
                  <SelectItem value="pending">Pending</SelectItem>
                  <SelectItem value="under_review">Under Review</SelectItem>
                  <SelectItem value="approved">Approved</SelectItem>
                  <SelectItem value="rejected">Rejected</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </Card>

          {/* Requests List */}
          <div className="space-y-4">
            {filteredRequests.length === 0 ? (
              <Card className="p-12 text-center border-gray-200">
                <FileText className="w-16 h-16 text-gray-300 mx-auto mb-4" />
                <h3 className="text-lg font-semibold text-gray-900 mb-2">No requests found</h3>
                <p className="text-gray-500 mb-6">
                  {searchQuery || statusFilter !== 'all'
                    ? 'Try adjusting your filters'
                    : 'Create your first request to get started'}
                </p>
                <Link to="/agency/upload">
                  <Button className="bg-blue-600 hover:bg-blue-700 text-white">
                    <Plus className="w-4 h-4 mr-2" />
                    Create New Request
                  </Button>
                </Link>
              </Card>
            ) : (
              filteredRequests.map((request, index) => (
                <motion.div
                  key={request.id}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: index * 0.05 }}
                >
                  <Card className="p-6 border-gray-200 hover:shadow-md transition-shadow">
                    <div className="flex items-start justify-between mb-4">
                      <div className="flex items-center gap-3">
                        {getStatusIcon(request.status)}
                        <div>
                          <h3 className="font-bold text-gray-900">{request.id}</h3>
                          <p className="text-sm text-gray-500">
                            Submitted on {new Date(request.submittedDate).toLocaleDateString('en-IN', {
                              day: 'numeric',
                              month: 'short',
                              year: 'numeric',
                            })}
                          </p>
                        </div>
                      </div>
                      {getStatusBadge(request.status)}
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                      <div>
                        <p className="text-sm text-gray-500">Total Amount</p>
                        <p className="font-semibold text-gray-900">
                          ₹{request.totalAmount.toLocaleString('en-IN')}
                        </p>
                      </div>
                      <div>
                        <p className="text-sm text-gray-500">AI Confidence</p>
                        <p className="font-semibold text-gray-900">{request.aiConfidence}%</p>
                      </div>
                      <div>
                        <p className="text-sm text-gray-500">Documents</p>
                        <div className="flex gap-1 mt-1">
                          {Object.entries(request.documents).map(([key, value]) => (
                            <div
                              key={key}
                              className={`w-2 h-2 rounded-full ${
                                value ? 'bg-green-500' : 'bg-gray-300'
                              }`}
                              title={key}
                            />
                          ))}
                        </div>
                      </div>
                    </div>

                    {request.reviewedBy && (
                      <div className="pt-4 border-t border-gray-100">
                        <div className="flex items-start justify-between">
                          <div>
                            <p className="text-sm text-gray-500">Reviewed by</p>
                            <p className="text-sm font-medium text-gray-900">{request.reviewedBy}</p>
                            <p className="text-xs text-gray-400">
                              on {new Date(request.reviewDate!).toLocaleDateString('en-IN', {
                                day: 'numeric',
                                month: 'short',
                                year: 'numeric',
                              })}
                            </p>
                          </div>
                          {request.remarks && (
                            <div className="max-w-md">
                              <p className="text-sm text-gray-500">Remarks</p>
                              <p className="text-sm text-gray-700 mt-1">{request.remarks}</p>
                            </div>
                          )}
                        </div>
                      </div>
                    )}
                  </Card>
                </motion.div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}