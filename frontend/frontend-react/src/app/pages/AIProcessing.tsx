import { useEffect, useState } from 'react';
import { useNavigate, useParams, Link } from 'react-router';
import { Brain, CheckCircle, AlertTriangle, XCircle, ChevronLeft, Loader2 } from 'lucide-react';
import { Card } from '../components/ui/card';
import { Progress } from '../components/ui/progress';
import { Badge } from '../components/ui/badge';
import { motion } from 'motion/react';

interface ProcessingStep {
  name: string;
  status: 'pending' | 'processing' | 'complete';
  progress: number;
}

export default function AIProcessing() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [steps, setSteps] = useState<ProcessingStep[]>([
    { name: 'Document Upload', status: 'complete', progress: 100 },
    { name: 'Data Extraction', status: 'pending', progress: 0 },
    { name: 'PO Validation', status: 'pending', progress: 0 },
    { name: 'Invoice Validation', status: 'pending', progress: 0 },
    { name: 'Cost Summary Analysis', status: 'pending', progress: 0 },
    { name: 'Photo Quality Check', status: 'pending', progress: 0 },
    { name: 'Confidence Scoring', status: 'pending', progress: 0 },
  ]);

  const [overallProgress, setOverallProgress] = useState(14);
  const [analysisComplete, setAnalysisComplete] = useState(false);

  useEffect(() => {
    // Simulate AI processing
    const processSteps = async () => {
      for (let i = 1; i < steps.length; i++) {
        await new Promise((resolve) => setTimeout(resolve, 1500));
        
        setSteps((prev) =>
          prev.map((step, idx) => {
            if (idx === i) {
              return { ...step, status: 'processing', progress: 50 };
            }
            return step;
          })
        );

        await new Promise((resolve) => setTimeout(resolve, 1000));
        
        setSteps((prev) =>
          prev.map((step, idx) => {
            if (idx === i) {
              return { ...step, status: 'complete', progress: 100 };
            }
            return step;
          })
        );

        setOverallProgress(((i + 1) / steps.length) * 100);
      }

      setAnalysisComplete(true);
      
      // Redirect to ASM review after completion
      setTimeout(() => {
        navigate('/asm/review');
      }, 2000);
    };

    processSteps();
  }, [navigate, steps.length]);

  const getStatusIcon = (status: string) => {
    if (status === 'complete') {
      return <CheckCircle className="w-5 h-5 text-green-600" />;
    } else if (status === 'processing') {
      return <Loader2 className="w-5 h-5 text-blue-600 animate-spin" />;
    }
    return <div className="w-5 h-5 rounded-full border-2 border-gray-300" />;
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-white">
      {/* Header */}
      <header className="bg-white border-b border-blue-100 shadow-sm">
        <div className="max-w-4xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <Link to="/" className="flex items-center gap-2 text-blue-600 hover:text-blue-700">
              <ChevronLeft className="w-5 h-5" />
              <span>Back to Dashboard</span>
            </Link>
            <div className="flex items-center gap-2">
              <Brain className="w-5 h-5 text-blue-600" />
              <span className="font-semibold text-blue-900">AI Processing</span>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <div className="max-w-4xl mx-auto px-6 py-8">
        <div className="text-center mb-8">
          <motion.div
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ duration: 0.5 }}
            className="w-20 h-20 bg-gradient-to-br from-blue-600 to-blue-800 rounded-full flex items-center justify-center mx-auto mb-4"
          >
            <Brain className="w-10 h-10 text-white" />
          </motion.div>
          <h1 className="text-3xl font-bold text-blue-900 mb-2">
            AI Document Analysis in Progress
          </h1>
          <p className="text-blue-600">
            Document ID: {id}
          </p>
        </div>

        {/* Overall Progress */}
        <Card className="p-6 mb-6 border-blue-100">
          <div className="flex items-center justify-between mb-3">
            <span className="font-semibold text-blue-900">Overall Progress</span>
            <span className="text-blue-600">{Math.round(overallProgress)}%</span>
          </div>
          <Progress value={overallProgress} className="h-3" />
        </Card>

        {/* Processing Steps */}
        <Card className="p-6 mb-6 border-blue-100">
          <h2 className="text-xl font-bold text-blue-900 mb-6">Processing Steps</h2>
          <div className="space-y-4">
            {steps.map((step, index) => (
              <motion.div
                key={step.name}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: index * 0.1 }}
                className="flex items-center gap-4"
              >
                <div className="flex-shrink-0">
                  {getStatusIcon(step.status)}
                </div>
                <div className="flex-1">
                  <div className="flex items-center justify-between mb-2">
                    <span className={`font-medium ${
                      step.status === 'complete' ? 'text-green-700' :
                      step.status === 'processing' ? 'text-blue-700' :
                      'text-gray-500'
                    }`}>
                      {step.name}
                    </span>
                    <span className="text-sm text-gray-500">{step.progress}%</span>
                  </div>
                  <Progress value={step.progress} className="h-2" />
                </div>
              </motion.div>
            ))}
          </div>
        </Card>

        {/* Analysis Complete Message */}
        {analysisComplete && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
          >
            <Card className="p-6 bg-gradient-to-r from-green-50 to-blue-50 border-green-200">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 bg-green-600 rounded-full flex items-center justify-center flex-shrink-0">
                  <CheckCircle className="w-7 h-7 text-white" />
                </div>
                <div className="flex-1">
                  <h3 className="font-bold text-green-900 mb-1">
                    Analysis Complete!
                  </h3>
                  <p className="text-green-700">
                    Document has been validated and is ready for ASM review. Redirecting...
                  </p>
                </div>
              </div>
            </Card>
          </motion.div>
        )}

        {/* AI Info Card */}
        <Card className="p-6 bg-blue-50 border-blue-200">
          <div className="flex gap-4">
            <Brain className="w-6 h-6 text-blue-600 flex-shrink-0 mt-1" />
            <div>
              <h3 className="font-bold text-blue-900 mb-2">
                AI-Powered Validation
              </h3>
              <p className="text-sm text-blue-700 mb-3">
                Our AI system is analyzing your documents using advanced machine learning algorithms to:
              </p>
              <ul className="text-sm text-blue-700 space-y-1">
                <li>• Extract key data from Purchase Orders, Invoices, and Cost Summaries</li>
                <li>• Cross-validate amounts and dates across all documents</li>
                <li>• Verify photo quality and authenticity</li>
                <li>• Calculate confidence scores based on historical data</li>
                <li>• Identify potential discrepancies or issues</li>
              </ul>
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}
