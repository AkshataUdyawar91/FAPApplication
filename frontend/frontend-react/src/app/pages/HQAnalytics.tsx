import { Link } from 'react-router';
import { ChevronLeft, TrendingUp, Brain, CheckCircle, XCircle, AlertTriangle, BarChart3, DollarSign, LogOut } from 'lucide-react';
import { Card } from '../components/ui/card';
import { Badge } from '../components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../components/ui/tabs';
import { LineChart, Line, BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { analyticsData } from '../data/mockData';
import { Button } from '../components/ui/button';
import { useAuth } from '../context/AuthContext';
import { useNavigate } from 'react-router';
import { motion } from 'motion/react';

export default function HQAnalytics() {
  const navigate = useNavigate();
  const { user, logout } = useAuth();

  const handleLogout = () => {
    logout();
    navigate('/');
  };

  const COLORS = {
    approved: '#10b981',
    rejected: '#ef4444',
    pending: '#f59e0b',
    blue: '#3b82f6',
    lightBlue: '#60a5fa',
    darkBlue: '#1e40af',
  };

  const approvalData = [
    { name: 'Approved', value: analyticsData.overview.approved, color: COLORS.approved },
    { name: 'Rejected', value: analyticsData.overview.rejected, color: COLORS.rejected },
    { name: 'Pending', value: analyticsData.overview.pending, color: COLORS.pending },
  ];

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
              <div className="flex items-center gap-2">
                <BarChart3 className="w-5 h-5 text-white" />
                <span className="font-semibold text-white">HQ Analytics Dashboard</span>
              </div>
              <div
                onClick={handleLogout}
                style={{ 
                  backgroundColor: '#ffffff',
                  color: '#1e3a8a',
                  border: '1px solid #ffffff',
                  padding: '8px 16px',
                  borderRadius: '6px',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  fontWeight: '500',
                  fontSize: '16px'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.backgroundColor = '#eff6ff';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.backgroundColor = '#ffffff';
                }}
              >
                <LogOut style={{ width: '16px', height: '16px', color: '#1e3a8a' }} />
                <span style={{ color: '#1e3a8a' }}>Logout</span>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-6 py-8">
        {/* Overview Stats */}
        <div className="grid md:grid-cols-4 gap-6 mb-8">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1 }}
          >
            <Card className="p-6 border-blue-100">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-blue-600 mb-1">Total Submissions</p>
                  <p className="text-3xl font-bold text-blue-900">
                    {analyticsData.overview.totalSubmissions}
                  </p>
                  <p className="text-xs text-green-600 mt-1">↑ 12% vs last month</p>
                </div>
                <BarChart3 className="w-10 h-10 text-blue-400" />
              </div>
            </Card>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2 }}
          >
            <Card className="p-6 border-blue-100">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-blue-600 mb-1">Approved</p>
                  <p className="text-3xl font-bold text-green-600">
                    {analyticsData.overview.approved}
                  </p>
                  <p className="text-xs text-blue-600 mt-1">
                    {Math.round((analyticsData.overview.approved / analyticsData.overview.totalSubmissions) * 100)}% approval rate
                  </p>
                </div>
                <CheckCircle className="w-10 h-10 text-green-400" />
              </div>
            </Card>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 }}
          >
            <Card className="p-6 border-blue-100">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-blue-600 mb-1">Total Amount</p>
                  <p className="text-2xl font-bold text-blue-900">
                    ₹{(analyticsData.overview.totalAmount / 10000000).toFixed(1)}Cr
                  </p>
                  <p className="text-xs text-blue-600 mt-1">
                    ₹{(analyticsData.overview.approvedAmount / 10000000).toFixed(1)}Cr approved
                  </p>
                </div>
                <DollarSign className="w-10 h-10 text-blue-400" />
              </div>
            </Card>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4 }}
          >
            <Card className="p-6 border-blue-100">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-blue-600 mb-1">AI Confidence</p>
                  <p className="text-3xl font-bold text-blue-900">
                    {analyticsData.aiPerformance.averageConfidence}%
                  </p>
                  <p className="text-xs text-green-600 mt-1">↑ 3% improvement</p>
                </div>
                <Brain className="w-10 h-10 text-blue-400" />
              </div>
            </Card>
          </motion.div>
        </div>

        {/* Charts Section */}
        <Tabs defaultValue="trends" className="mb-8">
          <TabsList className="grid w-full md:w-auto md:inline-grid grid-cols-3">
            <TabsTrigger value="trends">Monthly Trends</TabsTrigger>
            <TabsTrigger value="distribution">Distribution</TabsTrigger>
            <TabsTrigger value="agencies">Top Agencies</TabsTrigger>
          </TabsList>

          <TabsContent value="trends" className="mt-6">
            <div className="grid lg:grid-cols-2 gap-6">
              {/* Submissions Trend */}
              <Card className="p-6 border-blue-100">
                <h3 className="text-lg font-bold text-blue-900 mb-4">Submission Trends</h3>
                <ResponsiveContainer width="100%" height={300}>
                  <LineChart data={analyticsData.monthlyTrends}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#e0e7ff" />
                    <XAxis dataKey="month" stroke="#3b82f6" />
                    <YAxis stroke="#3b82f6" />
                    <Tooltip 
                      contentStyle={{ 
                        backgroundColor: 'white', 
                        border: '1px solid #3b82f6',
                        borderRadius: '8px'
                      }}
                    />
                    <Legend />
                    <Line 
                      type="monotone" 
                      dataKey="submissions" 
                      stroke={COLORS.blue} 
                      strokeWidth={2}
                      name="Submissions"
                    />
                    <Line 
                      type="monotone" 
                      dataKey="approved" 
                      stroke={COLORS.approved} 
                      strokeWidth={2}
                      name="Approved"
                    />
                    <Line 
                      type="monotone" 
                      dataKey="rejected" 
                      stroke={COLORS.rejected} 
                      strokeWidth={2}
                      name="Rejected"
                    />
                  </LineChart>
                </ResponsiveContainer>
              </Card>

              {/* Amount Trend */}
              <Card className="p-6 border-blue-100">
                <h3 className="text-lg font-bold text-blue-900 mb-4">Amount Trends (₹ Lakhs)</h3>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={analyticsData.monthlyTrends}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#e0e7ff" />
                    <XAxis dataKey="month" stroke="#3b82f6" />
                    <YAxis stroke="#3b82f6" />
                    <Tooltip 
                      contentStyle={{ 
                        backgroundColor: 'white', 
                        border: '1px solid #3b82f6',
                        borderRadius: '8px'
                      }}
                      formatter={(value: number) => `₹${(value / 100000).toFixed(1)}L`}
                    />
                    <Bar dataKey="amount" fill={COLORS.blue} radius={[8, 8, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </Card>
            </div>
          </TabsContent>

          <TabsContent value="distribution" className="mt-6">
            <div className="grid lg:grid-cols-2 gap-6">
              {/* Approval Distribution */}
              <Card className="p-6 border-blue-100">
                <h3 className="text-lg font-bold text-blue-900 mb-4">Approval Distribution</h3>
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie
                      data={approvalData}
                      cx="50%"
                      cy="50%"
                      labelLine={false}
                      label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                      outerRadius={100}
                      fill="#8884d8"
                      dataKey="value"
                    >
                      {approvalData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              </Card>

              {/* Issue Breakdown */}
              <Card className="p-6 border-blue-100">
                <h3 className="text-lg font-bold text-blue-900 mb-4">Common Issues</h3>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={analyticsData.issueBreakdown} layout="vertical">
                    <CartesianGrid strokeDasharray="3 3" stroke="#e0e7ff" />
                    <XAxis type="number" stroke="#3b82f6" />
                    <YAxis dataKey="issue" type="category" stroke="#3b82f6" width={120} />
                    <Tooltip 
                      contentStyle={{ 
                        backgroundColor: 'white', 
                        border: '1px solid #3b82f6',
                        borderRadius: '8px'
                      }}
                    />
                    <Bar dataKey="count" fill={COLORS.rejected} radius={[0, 8, 8, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </Card>
            </div>
          </TabsContent>

          <TabsContent value="agencies" className="mt-6">
            <Card className="p-6 border-blue-100">
              <h3 className="text-lg font-bold text-blue-900 mb-4">Top Performing Agencies</h3>
              <div className="space-y-4">
                {analyticsData.topAgencies.map((agency, index) => (
                  <motion.div
                    key={agency.name}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: index * 0.1 }}
                    className="p-4 bg-blue-50 rounded-lg"
                  >
                    <div className="flex items-start justify-between mb-2">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 bg-blue-600 text-white rounded-full flex items-center justify-center font-bold">
                          {index + 1}
                        </div>
                        <div>
                          <h4 className="font-semibold text-blue-900">{agency.name}</h4>
                          <p className="text-sm text-blue-600">
                            {agency.submissions} submissions • {agency.approved} approved
                          </p>
                        </div>
                      </div>
                      <div className="text-right">
                        <p className="font-bold text-blue-900">
                          ₹{(agency.amount / 100000).toFixed(1)}L
                        </p>
                        <p className="text-xs text-green-600">
                          {Math.round((agency.approved / agency.submissions) * 100)}% approved
                        </p>
                      </div>
                    </div>
                    <div className="mt-2">
                      <div className="h-2 bg-blue-200 rounded-full overflow-hidden">
                        <div 
                          className="h-full bg-green-500 rounded-full transition-all"
                          style={{ width: `${(agency.approved / agency.submissions) * 100}%` }}
                        />
                      </div>
                    </div>
                  </motion.div>
                ))}
              </div>
            </Card>
          </TabsContent>
        </Tabs>

        {/* AI Performance Metrics */}
        <Card className="p-6 border-blue-100 mb-8">
          <div className="flex items-center gap-3 mb-6">
            <Brain className="w-6 h-6 text-blue-600" />
            <h2 className="text-xl font-bold text-blue-900">AI Performance Metrics</h2>
          </div>

          <div className="grid md:grid-cols-4 gap-6">
            <div className="p-4 bg-gradient-to-br from-blue-50 to-blue-100 rounded-lg">
              <p className="text-sm text-blue-600 mb-2">Average Confidence</p>
              <p className="text-3xl font-bold text-blue-900 mb-1">
                {analyticsData.aiPerformance.averageConfidence}%
              </p>
              <Badge className="bg-green-100 text-green-800 text-xs">
                <TrendingUp className="w-3 h-3 mr-1" />
                +3% vs last month
              </Badge>
            </div>

            <div className="p-4 bg-gradient-to-br from-green-50 to-green-100 rounded-lg">
              <p className="text-sm text-green-700 mb-2">Accuracy Rate</p>
              <p className="text-3xl font-bold text-green-900 mb-1">
                {analyticsData.aiPerformance.accuracyRate}%
              </p>
              <p className="text-xs text-green-600">
                AI predictions match ASM decisions
              </p>
            </div>

            <div className="p-4 bg-gradient-to-br from-purple-50 to-purple-100 rounded-lg">
              <p className="text-sm text-purple-700 mb-2">Processing Time</p>
              <p className="text-3xl font-bold text-purple-900 mb-1">
                {analyticsData.aiPerformance.processingTime}
              </p>
              <p className="text-xs text-purple-600">
                Average per document
              </p>
            </div>

            <div className="p-4 bg-gradient-to-br from-yellow-50 to-yellow-100 rounded-lg">
              <p className="text-sm text-yellow-700 mb-2">Flagged for Review</p>
              <p className="text-3xl font-bold text-yellow-900 mb-1">
                {analyticsData.aiPerformance.flaggedForReview}
              </p>
              <p className="text-xs text-yellow-600">
                {Math.round((analyticsData.aiPerformance.flaggedForReview / analyticsData.overview.totalSubmissions) * 100)}% of total submissions
              </p>
            </div>
          </div>
        </Card>

        {/* System Insights */}
        <div className="grid md:grid-cols-2 gap-6">
          <Card className="p-6 bg-gradient-to-br from-blue-50 to-white border-blue-200">
            <h3 className="text-lg font-bold text-blue-900 mb-4">💡 Key Insights</h3>
            <ul className="space-y-3 text-sm text-blue-700">
              <li className="flex items-start gap-2">
                <CheckCircle className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
                <span>AI confidence has improved by 3% this month, reducing manual review time</span>
              </li>
              <li className="flex items-start gap-2">
                <AlertTriangle className="w-5 h-5 text-yellow-600 flex-shrink-0 mt-0.5" />
                <span>15 documents flagged for amount mismatches - most common issue this month</span>
              </li>
              <li className="flex items-start gap-2">
                <TrendingUp className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
                <span>Creative Marketing Solutions maintains highest approval rate at 95%</span>
              </li>
              <li className="flex items-start gap-2">
                <Brain className="w-5 h-5 text-purple-600 flex-shrink-0 mt-0.5" />
                <span>AI accuracy rate of 94% shows strong correlation with ASM decisions</span>
              </li>
            </ul>
          </Card>

          <Card className="p-6 bg-gradient-to-br from-green-50 to-white border-green-200">
            <h3 className="text-lg font-bold text-green-900 mb-4">📈 Recommendations</h3>
            <ul className="space-y-3 text-sm text-green-700">
              <li className="flex items-start gap-2">
                <span className="font-bold text-green-900">•</span>
                <span>Consider automating approvals for documents with AI confidence above 95%</span>
              </li>
              <li className="flex items-start gap-2">
                <span className="font-bold text-green-900">•</span>
                <span>Provide training to agencies on proper documentation to reduce rejection rate</span>
              </li>
              <li className="flex items-start gap-2">
                <span className="font-bold text-green-900">•</span>
                <span>Review photo quality requirements with agencies to improve submission quality</span>
              </li>
              <li className="flex items-start gap-2">
                <span className="font-bold text-green-900">•</span>
                <span>Schedule quarterly review meetings with top-performing agencies</span>
              </li>
            </ul>
          </Card>
        </div>
      </div>
    </div>
  );
}