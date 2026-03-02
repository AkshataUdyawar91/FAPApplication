import { useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router';
import { ChevronLeft, FileText, Image as ImageIcon, CheckCircle, XCircle, AlertTriangle, Brain, Download } from 'lucide-react';
import { Card } from '../components/ui/card';
import { Badge } from '../components/ui/badge';
import { Button } from '../components/ui/button';
import { Textarea } from '../components/ui/textarea';
import { Label } from '../components/ui/label';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../components/ui/tabs';
import { toast } from 'sonner';
import { mockDocuments } from '../data/mockData';
import { motion } from 'motion/react';

export default function DocumentDetails() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [comments, setComments] = useState('');
  const [processing, setProcessing] = useState(false);

  const document = mockDocuments.find((doc) => doc.id === id);

  if (!document) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 to-white flex items-center justify-center">
        <Card className="p-8 text-center">
          <p className="text-blue-600">Document not found</p>
          <Link to="/asm/review">
            <Button className="mt-4 bg-blue-600 hover:bg-blue-700 text-white">
              Back to Review
            </Button>
          </Link>
        </Card>
      </div>
    );
  }

  const handleApprove = async () => {
    if (!comments.trim()) {
      toast.error('Please add comments before approving');
      return;
    }

    setProcessing(true);
    await new Promise((resolve) => setTimeout(resolve, 1500));
    toast.success('Document approved successfully!');
    setTimeout(() => navigate('/asm/review'), 1000);
  };

  const handleReject = async () => {
    if (!comments.trim()) {
      toast.error('Please add comments before rejecting');
      return;
    }

    setProcessing(true);
    await new Promise((resolve) => setTimeout(resolve, 1500));
    toast.error('Document rejected');
    setTimeout(() => navigate('/asm/review'), 1000);
  };

  const getValidationIcon = (status: string) => {
    switch (status) {
      case 'valid':
        return <CheckCircle className="w-5 h-5 text-green-600" />;
      case 'warning':
        return <AlertTriangle className="w-5 h-5 text-yellow-600" />;
      case 'invalid':
        return <XCircle className="w-5 h-5 text-red-600" />;
      default:
        return null;
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-white">
      {/* Header */}
      <header className="bg-white border-b border-blue-100 shadow-sm">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <Link to="/asm/review" className="flex items-center gap-2 text-blue-600 hover:text-blue-700">
              <ChevronLeft className="w-5 h-5" />
              <span>Back to Review Dashboard</span>
            </Link>
            <div className="flex items-center gap-2">
              <FileText className="w-5 h-5 text-blue-600" />
              <span className="font-semibold text-blue-900">Document Review</span>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-6 py-8">
        <div className="grid lg:grid-cols-3 gap-6">
          {/* Left Column - Document Details */}
          <div className="lg:col-span-2 space-y-6">
            {/* Document Header */}
            <Card className="p-6 border-blue-100">
              <div className="flex items-start justify-between mb-6">
                <div>
                  <h1 className="text-2xl font-bold text-blue-900 mb-2">
                    {document.agencyName}
                  </h1>
                  <p className="text-blue-600">Document ID: {document.id}</p>
                </div>
                <Badge className="bg-yellow-100 text-yellow-800">
                  {document.status === 'asm-review' ? 'Pending Review' : document.status}
                </Badge>
              </div>

              <div className="grid md:grid-cols-2 gap-4">
                <div>
                  <p className="text-sm text-blue-600 mb-1">Submission Date</p>
                  <p className="font-semibold text-blue-900">
                    {new Date(document.submittedDate).toLocaleDateString('en-IN', {
                      year: 'numeric',
                      month: 'long',
                      day: 'numeric'
                    })}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-blue-600 mb-1">Total Amount</p>
                  <p className="text-2xl font-bold text-blue-900">
                    ₹{document.amount.toLocaleString('en-IN')}
                  </p>
                </div>
              </div>
            </Card>

            {/* AI Analysis */}
            {document.aiAnalysis && (
              <Card className="p-6 border-blue-100">
                <div className="flex items-center gap-3 mb-6">
                  <Brain className="w-6 h-6 text-blue-600" />
                  <h2 className="text-xl font-bold text-blue-900">AI Analysis Results</h2>
                </div>

                {/* Confidence Score */}
                <div className="mb-6 p-4 bg-gradient-to-r from-blue-50 to-blue-100 rounded-lg">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm text-blue-600 mb-1">AI Confidence Score</p>
                      <p className="text-3xl font-bold text-blue-900">
                        {document.aiAnalysis.confidence}%
                      </p>
                    </div>
                    <div className={`text-right ${
                      document.aiAnalysis.recommendation === 'approve' ? 'text-green-600' :
                      document.aiAnalysis.recommendation === 'reject' ? 'text-red-600' :
                      'text-yellow-600'
                    }`}>
                      <p className="text-sm mb-1">Recommendation</p>
                      <p className="text-xl font-bold capitalize">
                        {document.aiAnalysis.recommendation}
                      </p>
                    </div>
                  </div>
                </div>

                {/* Validation Tabs */}
                <Tabs defaultValue="po" className="w-full">
                  <TabsList className="grid w-full grid-cols-4">
                    <TabsTrigger value="po">PO</TabsTrigger>
                    <TabsTrigger value="invoice">Invoice</TabsTrigger>
                    <TabsTrigger value="cost">Cost Summary</TabsTrigger>
                    <TabsTrigger value="photos">Photos</TabsTrigger>
                  </TabsList>

                  <TabsContent value="po" className="space-y-4 mt-4">
                    <div className="flex items-start gap-3">
                      {getValidationIcon(document.aiAnalysis.poValidation.status)}
                      <div className="flex-1">
                        <h3 className="font-semibold text-blue-900 mb-3">Purchase Order Validation</h3>
                        <div className="space-y-2 text-sm">
                          <div className="flex justify-between">
                            <span className="text-blue-600">PO Number:</span>
                            <span className="font-medium text-blue-900">{document.aiAnalysis.poValidation.poNumber}</span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-blue-600">Amount:</span>
                            <span className="font-medium text-blue-900">₹{document.aiAnalysis.poValidation.amount.toLocaleString('en-IN')}</span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-blue-600">Date:</span>
                            <span className="font-medium text-blue-900">{document.aiAnalysis.poValidation.date}</span>
                          </div>
                        </div>
                        {document.aiAnalysis.poValidation.issues && (
                          <div className="mt-3 p-3 bg-red-50 rounded-lg">
                            <p className="text-sm font-semibold text-red-900 mb-1">Issues Found:</p>
                            {document.aiAnalysis.poValidation.issues.map((issue, idx) => (
                              <p key={idx} className="text-sm text-red-700">• {issue}</p>
                            ))}
                          </div>
                        )}
                      </div>
                    </div>
                  </TabsContent>

                  <TabsContent value="invoice" className="space-y-4 mt-4">
                    <div className="flex items-start gap-3">
                      {getValidationIcon(document.aiAnalysis.invoiceValidation.status)}
                      <div className="flex-1">
                        <h3 className="font-semibold text-blue-900 mb-3">Invoice Validation</h3>
                        <div className="space-y-2 text-sm">
                          <div className="flex justify-between">
                            <span className="text-blue-600">Invoice Number:</span>
                            <span className="font-medium text-blue-900">{document.aiAnalysis.invoiceValidation.invoiceNumber}</span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-blue-600">Amount:</span>
                            <span className="font-medium text-blue-900">₹{document.aiAnalysis.invoiceValidation.amount.toLocaleString('en-IN')}</span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-blue-600">Date:</span>
                            <span className="font-medium text-blue-900">{document.aiAnalysis.invoiceValidation.date}</span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-blue-600">Matches PO:</span>
                            <span className={`font-medium ${document.aiAnalysis.invoiceValidation.matchesPO ? 'text-green-600' : 'text-red-600'}`}>
                              {document.aiAnalysis.invoiceValidation.matchesPO ? 'Yes' : 'No'}
                            </span>
                          </div>
                        </div>
                        {document.aiAnalysis.invoiceValidation.issues && (
                          <div className="mt-3 p-3 bg-yellow-50 rounded-lg">
                            <p className="text-sm font-semibold text-yellow-900 mb-1">Issues Found:</p>
                            {document.aiAnalysis.invoiceValidation.issues.map((issue, idx) => (
                              <p key={idx} className="text-sm text-yellow-700">• {issue}</p>
                            ))}
                          </div>
                        )}
                      </div>
                    </div>
                  </TabsContent>

                  <TabsContent value="cost" className="space-y-4 mt-4">
                    <div className="flex items-start gap-3">
                      {getValidationIcon(document.aiAnalysis.costSummaryValidation.status)}
                      <div className="flex-1">
                        <h3 className="font-semibold text-blue-900 mb-3">Cost Summary Validation</h3>
                        <div className="space-y-2 text-sm mb-3">
                          <div className="flex justify-between">
                            <span className="text-blue-600">Total Amount:</span>
                            <span className="font-medium text-blue-900">₹{document.aiAnalysis.costSummaryValidation.totalAmount.toLocaleString('en-IN')}</span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-blue-600">Matches Invoice:</span>
                            <span className={`font-medium ${document.aiAnalysis.costSummaryValidation.matchesInvoice ? 'text-green-600' : 'text-red-600'}`}>
                              {document.aiAnalysis.costSummaryValidation.matchesInvoice ? 'Yes' : 'No'}
                            </span>
                          </div>
                        </div>
                        <div className="p-3 bg-blue-50 rounded-lg">
                          <p className="text-sm font-semibold text-blue-900 mb-2">Cost Breakdown:</p>
                          {document.aiAnalysis.costSummaryValidation.breakdown.map((item, idx) => (
                            <div key={idx} className="flex justify-between text-sm mb-1">
                              <span className="text-blue-700">{item.item}</span>
                              <span className="font-medium text-blue-900">₹{item.amount.toLocaleString('en-IN')}</span>
                            </div>
                          ))}
                        </div>
                        {document.aiAnalysis.costSummaryValidation.issues && (
                          <div className="mt-3 p-3 bg-yellow-50 rounded-lg">
                            <p className="text-sm font-semibold text-yellow-900 mb-1">Issues Found:</p>
                            {document.aiAnalysis.costSummaryValidation.issues.map((issue, idx) => (
                              <p key={idx} className="text-sm text-yellow-700">• {issue}</p>
                            ))}
                          </div>
                        )}
                      </div>
                    </div>
                  </TabsContent>

                  <TabsContent value="photos" className="space-y-4 mt-4">
                    <div className="flex items-start gap-3">
                      {getValidationIcon(document.aiAnalysis.photoValidation.status)}
                      <div className="flex-1">
                        <h3 className="font-semibold text-blue-900 mb-3">Photo Quality Check</h3>
                        <div className="space-y-2 text-sm">
                          <div className="flex justify-between">
                            <span className="text-blue-600">Photos Uploaded:</span>
                            <span className="font-medium text-blue-900">{document.aiAnalysis.photoValidation.photoCount}</span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-blue-600">Quality Score:</span>
                            <span className="font-medium text-blue-900">{document.aiAnalysis.photoValidation.qualityScore}%</span>
                          </div>
                        </div>
                        {document.aiAnalysis.photoValidation.issues && (
                          <div className="mt-3 p-3 bg-yellow-50 rounded-lg">
                            <p className="text-sm font-semibold text-yellow-900 mb-1">Issues Found:</p>
                            {document.aiAnalysis.photoValidation.issues.map((issue, idx) => (
                              <p key={idx} className="text-sm text-yellow-700">• {issue}</p>
                            ))}
                          </div>
                        )}
                      </div>
                    </div>
                  </TabsContent>
                </Tabs>

                {/* Flags */}
                {document.aiAnalysis.flags.length > 0 && (
                  <div className="mt-6 p-4 bg-orange-50 border border-orange-200 rounded-lg">
                    <p className="font-semibold text-orange-900 mb-2">⚠️ Flagged Issues</p>
                    <div className="flex flex-wrap gap-2">
                      {document.aiAnalysis.flags.map((flag) => (
                        <Badge key={flag} variant="outline" className="text-orange-700 border-orange-300">
                          {flag}
                        </Badge>
                      ))}
                    </div>
                  </div>
                )}
              </Card>
            )}

            {/* Document Files */}
            <Card className="p-6 border-blue-100">
              <h2 className="text-xl font-bold text-blue-900 mb-4">Submitted Documents</h2>
              <div className="space-y-3">
                <div className="flex items-center justify-between p-3 bg-blue-50 rounded-lg">
                  <div className="flex items-center gap-3">
                    <FileText className="w-5 h-5 text-blue-600" />
                    <span className="font-medium text-blue-900">Purchase Order</span>
                  </div>
                  <Button variant="outline" size="sm" className="border-blue-300 text-blue-700">
                    <Download className="w-4 h-4 mr-2" />
                    Download
                  </Button>
                </div>
                <div className="flex items-center justify-between p-3 bg-blue-50 rounded-lg">
                  <div className="flex items-center gap-3">
                    <FileText className="w-5 h-5 text-blue-600" />
                    <span className="font-medium text-blue-900">Invoice</span>
                  </div>
                  <Button variant="outline" size="sm" className="border-blue-300 text-blue-700">
                    <Download className="w-4 h-4 mr-2" />
                    Download
                  </Button>
                </div>
                <div className="flex items-center justify-between p-3 bg-blue-50 rounded-lg">
                  <div className="flex items-center gap-3">
                    <FileText className="w-5 h-5 text-blue-600" />
                    <span className="font-medium text-blue-900">Cost Summary</span>
                  </div>
                  <Button variant="outline" size="sm" className="border-blue-300 text-blue-700">
                    <Download className="w-4 h-4 mr-2" />
                    Download
                  </Button>
                </div>
                <div className="flex items-center justify-between p-3 bg-blue-50 rounded-lg">
                  <div className="flex items-center gap-3">
                    <ImageIcon className="w-5 h-5 text-blue-600" />
                    <span className="font-medium text-blue-900">
                      Photos ({typeof document.documents.photos === 'object' && Array.isArray(document.documents.photos) ? document.documents.photos.length : 0})
                    </span>
                  </div>
                  <Button variant="outline" size="sm" className="border-blue-300 text-blue-700">
                    <Download className="w-4 h-4 mr-2" />
                    Download All
                  </Button>
                </div>
              </div>
            </Card>
          </div>

          {/* Right Column - Action Panel */}
          <div className="space-y-6">
            {document.status === 'asm-review' ? (
              <Card className="p-6 border-blue-100 sticky top-6">
                <h2 className="text-xl font-bold text-blue-900 mb-4">Review Decision</h2>
                <div className="space-y-4">
                  <div>
                    <Label htmlFor="comments" className="text-blue-700 mb-2">
                      Comments *
                    </Label>
                    <Textarea
                      id="comments"
                      placeholder="Add your review comments here..."
                      value={comments}
                      onChange={(e) => setComments(e.target.value)}
                      className="h-32 border-blue-200"
                    />
                  </div>

                  <div className="space-y-3">
                    <Button
                      onClick={handleApprove}
                      disabled={processing}
                      className="w-full bg-green-600 hover:bg-green-700 text-white"
                    >
                      <CheckCircle className="w-4 h-4 mr-2" />
                      Approve Payment
                    </Button>
                    <Button
                      onClick={handleReject}
                      disabled={processing}
                      variant="outline"
                      className="w-full border-red-300 text-red-700 hover:bg-red-50"
                    >
                      <XCircle className="w-4 h-4 mr-2" />
                      Reject Submission
                    </Button>
                  </div>
                </div>
              </Card>
            ) : (
              <Card className="p-6 border-blue-100 sticky top-6">
                <h2 className="text-xl font-bold text-blue-900 mb-4">Decision History</h2>
                {document.asmDecision && (
                  <div className="space-y-3">
                    <div>
                      <p className="text-sm text-blue-600 mb-1">Status</p>
                      <Badge className={document.asmDecision.action === 'approved' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}>
                        {document.asmDecision.action}
                      </Badge>
                    </div>
                    <div>
                      <p className="text-sm text-blue-600 mb-1">Reviewed By</p>
                      <p className="font-medium text-blue-900">{document.asmDecision.officer}</p>
                    </div>
                    <div>
                      <p className="text-sm text-blue-600 mb-1">Date</p>
                      <p className="font-medium text-blue-900">
                        {new Date(document.asmDecision.date).toLocaleDateString('en-IN')}
                      </p>
                    </div>
                    <div>
                      <p className="text-sm text-blue-600 mb-1">Comments</p>
                      <p className="text-sm text-blue-900">{document.asmDecision.comments}</p>
                    </div>
                  </div>
                )}
              </Card>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
