import { Link } from 'react-router';
import { Upload, Brain, CheckCircle, BarChart3, FileCheck, Clock } from 'lucide-react';
import { Button } from '../components/ui/button';
import { Card } from '../components/ui/card';

export default function Dashboard() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-white">
      {/* Header */}
      <header className="bg-white border-b border-blue-100 shadow-sm">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 bg-gradient-to-br from-blue-600 to-blue-800 rounded-lg flex items-center justify-center">
                <FileCheck className="w-7 h-7 text-white" />
              </div>
              <div>
                <h1 className="font-bold text-xl text-blue-900">Bajaj Auto Limited</h1>
                <p className="text-sm text-blue-600">Document Approval System</p>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <div className="max-w-7xl mx-auto px-6 py-12">
        <div className="text-center mb-12">
          <h2 className="text-4xl font-bold text-blue-900 mb-4">
            AI-Powered Document Approval
          </h2>
          <p className="text-lg text-blue-700 max-w-2xl mx-auto">
            Streamline your reimbursement process with intelligent document validation
            and automated approval workflows
          </p>
        </div>

        {/* Role Cards */}
        <div className="grid md:grid-cols-3 gap-6 mb-12">
          {/* Agency Portal */}
          <Card className="p-8 hover:shadow-xl transition-all border-2 border-blue-100 hover:border-blue-300">
            <div className="flex flex-col items-center text-center">
              <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mb-4">
                <Upload className="w-8 h-8 text-blue-600" />
              </div>
              <h3 className="text-xl font-bold text-blue-900 mb-2">
                Agency Portal
              </h3>
              <p className="text-blue-600 mb-6">
                Submit reimbursement documents for AI validation and approval
              </p>
              <Link to="/agency/upload" className="w-full">
                <Button className="w-full bg-blue-600 hover:bg-blue-700 text-white">
                  Upload Documents
                </Button>
              </Link>
            </div>
          </Card>

          {/* ASM Review */}
          <Card className="p-8 hover:shadow-xl transition-all border-2 border-blue-100 hover:border-blue-300">
            <div className="flex flex-col items-center text-center">
              <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mb-4">
                <CheckCircle className="w-8 h-8 text-blue-600" />
              </div>
              <h3 className="text-xl font-bold text-blue-900 mb-2">
                ASM Review
              </h3>
              <p className="text-blue-600 mb-6">
                Review AI recommendations and approve or reject submissions
              </p>
              <Link to="/asm/review" className="w-full">
                <Button className="w-full bg-blue-600 hover:bg-blue-700 text-white">
                  Review Documents
                </Button>
              </Link>
            </div>
          </Card>

          {/* HQ Analytics */}
          <Card className="p-8 hover:shadow-xl transition-all border-2 border-blue-100 hover:border-blue-300">
            <div className="flex flex-col items-center text-center">
              <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mb-4">
                <BarChart3 className="w-8 h-8 text-blue-600" />
              </div>
              <h3 className="text-xl font-bold text-blue-900 mb-2">
                HQ Analytics
              </h3>
              <p className="text-blue-600 mb-6">
                Monitor trends, performance metrics, and system insights
              </p>
              <Link to="/hq/analytics" className="w-full">
                <Button className="w-full bg-blue-600 hover:bg-blue-700 text-white">
                  View Analytics
                </Button>
              </Link>
            </div>
          </Card>
        </div>

        {/* Process Flow */}
        <Card className="p-8 bg-gradient-to-r from-blue-50 to-blue-100 border-blue-200">
          <h3 className="text-2xl font-bold text-blue-900 mb-8 text-center">
            How It Works
          </h3>
          <div className="grid md:grid-cols-4 gap-6">
            <div className="flex flex-col items-center text-center">
              <div className="w-14 h-14 bg-white rounded-full flex items-center justify-center mb-4 shadow-md">
                <Upload className="w-7 h-7 text-blue-600" />
              </div>
              <h4 className="font-bold text-blue-900 mb-2">1. Upload</h4>
              <p className="text-sm text-blue-700">
                Agency uploads PO, Invoice, Cost Summary, and Photos
              </p>
            </div>

            <div className="flex flex-col items-center text-center">
              <div className="w-14 h-14 bg-white rounded-full flex items-center justify-center mb-4 shadow-md">
                <Brain className="w-7 h-7 text-blue-600" />
              </div>
              <h4 className="font-bold text-blue-900 mb-2">2. AI Processing</h4>
              <p className="text-sm text-blue-700">
                AI extracts data, validates documents, and scores confidence
              </p>
            </div>

            <div className="flex flex-col items-center text-center">
              <div className="w-14 h-14 bg-white rounded-full flex items-center justify-center mb-4 shadow-md">
                <CheckCircle className="w-7 h-7 text-blue-600" />
              </div>
              <h4 className="font-bold text-blue-900 mb-2">3. ASM Review</h4>
              <p className="text-sm text-blue-700">
                ASM reviews AI recommendation and makes final decision
              </p>
            </div>

            <div className="flex flex-col items-center text-center">
              <div className="w-14 h-14 bg-white rounded-full flex items-center justify-center mb-4 shadow-md">
                <BarChart3 className="w-7 h-7 text-blue-600" />
              </div>
              <h4 className="font-bold text-blue-900 mb-2">4. HQ Monitoring</h4>
              <p className="text-sm text-blue-700">
                HQ tracks analytics, trends, and system performance
              </p>
            </div>
          </div>
        </Card>

        {/* Quick Stats */}
        <div className="grid md:grid-cols-4 gap-6 mt-8">
          <Card className="p-6 bg-white border-blue-100">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-blue-600 mb-1">Pending Review</p>
                <p className="text-3xl font-bold text-blue-900">12</p>
              </div>
              <Clock className="w-10 h-10 text-blue-400" />
            </div>
          </Card>

          <Card className="p-6 bg-white border-blue-100">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-blue-600 mb-1">AI Confidence</p>
                <p className="text-3xl font-bold text-blue-900">82%</p>
              </div>
              <Brain className="w-10 h-10 text-blue-400" />
            </div>
          </Card>

          <Card className="p-6 bg-white border-blue-100">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-blue-600 mb-1">This Month</p>
                <p className="text-3xl font-bold text-blue-900">34</p>
              </div>
              <FileCheck className="w-10 h-10 text-blue-400" />
            </div>
          </Card>

          <Card className="p-6 bg-white border-blue-100">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-blue-600 mb-1">Approval Rate</p>
                <p className="text-3xl font-bold text-blue-900">94%</p>
              </div>
              <CheckCircle className="w-10 h-10 text-blue-400" />
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
}
