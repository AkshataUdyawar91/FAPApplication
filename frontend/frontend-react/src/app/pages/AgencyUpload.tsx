import { useState } from 'react';
import { useNavigate, Link } from 'react-router';
import { Upload, FileText, Image, ChevronLeft, CheckCircle, X, ArrowRight, ArrowLeft } from 'lucide-react';
import { Button } from '../components/ui/button';
import { Card } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { toast } from 'sonner';
import { Progress } from '../components/ui/progress';
import { motion } from 'motion/react';
import { useAuth } from '../context/AuthContext';
import { AgencySidebar } from '../components/AgencySidebar';

export default function AgencyUpload() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const [currentStep, setCurrentStep] = useState(1);
  const [purchaseOrder, setPurchaseOrder] = useState<File | null>(null);
  const [invoice, setInvoice] = useState<File | null>(null);
  const [costSummary, setCostSummary] = useState<File | null>(null);
  const [photos, setPhotos] = useState<File[]>([]);
  const [additionalDocs, setAdditionalDocs] = useState<File[]>([]);
  const [uploading, setUploading] = useState(false);

  const steps = [
    { number: 1, title: 'Purchase Order', icon: FileText },
    { number: 2, title: 'Invoice', icon: FileText },
    { number: 3, title: 'Photos & Cost Summary', icon: Image },
    { number: 4, title: 'Additional Documents', icon: Upload },
  ];

  const handleFileChange = (
    e: React.ChangeEvent<HTMLInputElement>,
    setter: (file: File | null) => void
  ) => {
    const file = e.target.files?.[0] || null;
    setter(file);
  };

  const handlePhotosChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    setPhotos((prev) => [...prev, ...files]);
  };

  const handleAdditionalDocsChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    setAdditionalDocs((prev) => [...prev, ...files]);
  };

  const removePhoto = (index: number) => {
    setPhotos((prev) => prev.filter((_, i) => i !== index));
  };

  const removeAdditionalDoc = (index: number) => {
    setAdditionalDocs((prev) => prev.filter((_, i) => i !== index));
  };

  const handleNext = () => {
    if (currentStep === 1 && !purchaseOrder) {
      toast.error('Please upload Purchase Order');
      return;
    }
    if (currentStep === 2 && !invoice) {
      toast.error('Please upload Invoice');
      return;
    }
    if (currentStep === 3 && (!photos.length || !costSummary)) {
      toast.error('Please upload event photos and cost summary');
      return;
    }
    
    if (currentStep < 4) {
      setCurrentStep(currentStep + 1);
    }
  };

  const handleBack = () => {
    if (currentStep > 1) {
      setCurrentStep(currentStep - 1);
    }
  };

  const handleSubmit = async () => {
    if (!purchaseOrder || !invoice || !costSummary || photos.length === 0) {
      toast.error('Please complete all required steps');
      return;
    }

    setUploading(true);

    // Simulate upload process
    await new Promise((resolve) => setTimeout(resolve, 2000));

    toast.success('Documents submitted successfully! AI processing started.');
    
    // Navigate to AI processing page
    setTimeout(() => {
      navigate('/ai/processing/DOC006');
    }, 1000);
  };

  const progressPercentage = (currentStep / 4) * 100;

  return (
    <div className="flex min-h-screen bg-gray-50">
      <AgencySidebar />

      {/* Main Content */}
      <div className="flex-1 overflow-auto">
        {/* Header */}
        <header className="bg-white border-b border-gray-200 sticky top-0 z-10">
          <div className="px-8 py-6">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Create New Request</h1>
              <p className="text-sm text-gray-500 mt-1">
                Complete all steps to submit your documents for AI validation and ASM approval
              </p>
            </div>
          </div>
        </header>

        <div className="p-8">
          {/* Progress Bar */}
          <Card className="p-6 mb-6 border-gray-200">
            <div className="mb-6">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm font-medium text-gray-900">
                  Step {currentStep} of 4
                </span>
                <span className="text-sm text-gray-600">
                  {Math.round(progressPercentage)}% Complete
                </span>
              </div>
              <Progress value={progressPercentage} className="h-3" />
            </div>

            {/* Step Indicators */}
            <div className="grid grid-cols-4 gap-4">
              {steps.map((step) => {
                const StepIcon = step.icon;
                const isComplete = currentStep > step.number;
                const isCurrent = currentStep === step.number;
                
                return (
                  <div
                    key={step.number}
                    className={`flex flex-col items-center text-center ${
                      isComplete ? 'opacity-100' : isCurrent ? 'opacity-100' : 'opacity-40'
                    }`}
                  >
                    <div
                      className={`w-12 h-12 rounded-full flex items-center justify-center mb-2 ${
                        isComplete
                          ? 'bg-green-600'
                          : isCurrent
                          ? 'bg-blue-600'
                          : 'bg-gray-300'
                      }`}
                    >
                      {isComplete ? (
                        <CheckCircle className="w-6 h-6 text-white" />
                      ) : (
                        <StepIcon className="w-6 h-6 text-white" />
                      )}
                    </div>
                    <p className="text-xs font-medium text-blue-900">{step.title}</p>
                  </div>
                );
              })}
            </div>
          </Card>

          {/* Step Content */}
          <motion.div
            key={currentStep}
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            transition={{ duration: 0.3 }}
          >
            {/* Step 1: Purchase Order */}
            {currentStep === 1 && (
              <Card className="p-8 mb-6 border-blue-100">
                <div className="flex items-center gap-3 mb-6">
                  <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
                    <FileText className="w-6 h-6 text-blue-600" />
                  </div>
                  <div>
                    <h2 className="text-2xl font-bold text-blue-900">Upload Purchase Order</h2>
                    <p className="text-sm text-blue-600">Upload the official Purchase Order document</p>
                  </div>
                </div>

                <Label
                  htmlFor="purchaseOrder"
                  className="flex flex-col items-center justify-center h-64 border-2 border-dashed border-blue-300 rounded-lg cursor-pointer hover:bg-blue-50 transition-colors"
                >
                  {purchaseOrder ? (
                    <div className="text-center">
                      <CheckCircle className="w-16 h-16 text-green-600 mx-auto mb-4" />
                      <p className="text-lg text-blue-900 font-medium mb-2">{purchaseOrder.name}</p>
                      <p className="text-sm text-blue-600">
                        {(purchaseOrder.size / 1024).toFixed(2)} KB
                      </p>
                      <Button
                        type="button"
                        variant="outline"
                        className="mt-4 border-blue-300 text-blue-700"
                        onClick={(e) => {
                          e.preventDefault();
                          setPurchaseOrder(null);
                        }}
                      >
                        Change File
                      </Button>
                    </div>
                  ) : (
                    <div className="text-center">
                      <Upload className="w-16 h-16 text-blue-400 mx-auto mb-4" />
                      <p className="text-lg text-blue-900 font-medium mb-2">
                        Click to upload Purchase Order
                      </p>
                      <p className="text-sm text-blue-600">PDF format only</p>
                    </div>
                  )}
                </Label>
                <Input
                  id="purchaseOrder"
                  type="file"
                  accept=".pdf"
                  onChange={(e) => handleFileChange(e, setPurchaseOrder)}
                  className="hidden"
                />
              </Card>
            )}

            {/* Step 2: Invoice */}
            {currentStep === 2 && (
              <Card className="p-8 mb-6 border-blue-100">
                <div className="flex items-center gap-3 mb-6">
                  <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
                    <FileText className="w-6 h-6 text-blue-600" />
                  </div>
                  <div>
                    <h2 className="text-2xl font-bold text-blue-900">Upload Invoice</h2>
                    <p className="text-sm text-blue-600">Upload the invoice for reimbursement</p>
                  </div>
                </div>

                <Label
                  htmlFor="invoice"
                  className="flex flex-col items-center justify-center h-64 border-2 border-dashed border-blue-300 rounded-lg cursor-pointer hover:bg-blue-50 transition-colors"
                >
                  {invoice ? (
                    <div className="text-center">
                      <CheckCircle className="w-16 h-16 text-green-600 mx-auto mb-4" />
                      <p className="text-lg text-blue-900 font-medium mb-2">{invoice.name}</p>
                      <p className="text-sm text-blue-600">
                        {(invoice.size / 1024).toFixed(2)} KB
                      </p>
                      <Button
                        type="button"
                        variant="outline"
                        className="mt-4 border-blue-300 text-blue-700"
                        onClick={(e) => {
                          e.preventDefault();
                          setInvoice(null);
                        }}
                      >
                        Change File
                      </Button>
                    </div>
                  ) : (
                    <div className="text-center">
                      <Upload className="w-16 h-16 text-blue-400 mx-auto mb-4" />
                      <p className="text-lg text-blue-900 font-medium mb-2">
                        Click to upload Invoice
                      </p>
                      <p className="text-sm text-blue-600">PDF format only</p>
                    </div>
                  )}
                </Label>
                <Input
                  id="invoice"
                  type="file"
                  accept=".pdf"
                  onChange={(e) => handleFileChange(e, setInvoice)}
                  className="hidden"
                />
              </Card>
            )}

            {/* Step 3: Photos & Cost Summary */}
            {currentStep === 3 && (
              <div className="space-y-6">
                <Card className="p-8 border-blue-100">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
                      <Image className="w-6 h-6 text-blue-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-blue-900">Upload Event Photos</h2>
                      <p className="text-sm text-blue-600">Upload photos of the completed event/campaign</p>
                    </div>
                  </div>

                  <Label
                    htmlFor="photos"
                    className="flex flex-col items-center justify-center h-48 border-2 border-dashed border-blue-300 rounded-lg cursor-pointer hover:bg-blue-50 transition-colors"
                  >
                    {photos.length > 0 ? (
                      <div className="text-center">
                        <CheckCircle className="w-16 h-16 text-green-600 mx-auto mb-4" />
                        <p className="text-lg text-blue-900 font-medium mb-2">
                          {photos.length} photo{photos.length > 1 ? 's' : ''} uploaded
                        </p>
                        <p className="text-sm text-blue-600">Click to add more photos</p>
                      </div>
                    ) : (
                      <div className="text-center">
                        <Upload className="w-16 h-16 text-blue-400 mx-auto mb-4" />
                        <p className="text-lg text-blue-900 font-medium mb-2">
                          Click to upload Event Photos
                        </p>
                        <p className="text-sm text-blue-600">JPG, PNG format - Multiple files allowed</p>
                      </div>
                    )}
                  </Label>
                  <Input
                    id="photos"
                    type="file"
                    accept="image/*"
                    multiple
                    onChange={handlePhotosChange}
                    className="hidden"
                  />

                  {photos.length > 0 && (
                    <div className="mt-6">
                      <h3 className="font-semibold text-blue-900 mb-3">Uploaded Photos</h3>
                      <div className="grid grid-cols-4 gap-4">
                        {photos.map((photo, index) => (
                          <div key={index} className="relative group">
                            <img
                              src={URL.createObjectURL(photo)}
                              alt={`Photo ${index + 1}`}
                              className="w-full h-24 object-cover rounded-lg border-2 border-blue-200"
                            />
                            <button
                              type="button"
                              onClick={() => removePhoto(index)}
                              className="absolute top-1 right-1 bg-red-500 text-white rounded-full p-1 opacity-0 group-hover:opacity-100 transition-opacity"
                            >
                              <X className="w-4 h-4" />
                            </button>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </Card>

                <Card className="p-8 border-blue-100">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
                      <FileText className="w-6 h-6 text-blue-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-blue-900">Upload Cost Summary</h2>
                      <p className="text-sm text-blue-600">Upload detailed cost breakdown document</p>
                    </div>
                  </div>

                  <Label
                    htmlFor="costSummary"
                    className="flex flex-col items-center justify-center h-48 border-2 border-dashed border-blue-300 rounded-lg cursor-pointer hover:bg-blue-50 transition-colors"
                  >
                    {costSummary ? (
                      <div className="text-center">
                        <CheckCircle className="w-16 h-16 text-green-600 mx-auto mb-4" />
                        <p className="text-lg text-blue-900 font-medium mb-2">{costSummary.name}</p>
                        <p className="text-sm text-blue-600">
                          {(costSummary.size / 1024).toFixed(2)} KB
                        </p>
                        <Button
                          type="button"
                          variant="outline"
                          className="mt-4 border-blue-300 text-blue-700"
                          onClick={(e) => {
                            e.preventDefault();
                            setCostSummary(null);
                          }}
                        >
                          Change File
                        </Button>
                      </div>
                    ) : (
                      <div className="text-center">
                        <Upload className="w-16 h-16 text-blue-400 mx-auto mb-4" />
                        <p className="text-lg text-blue-900 font-medium mb-2">
                          Click to upload Cost Summary
                        </p>
                        <p className="text-sm text-blue-600">PDF format only</p>
                      </div>
                    )}
                  </Label>
                  <Input
                    id="costSummary"
                    type="file"
                    accept=".pdf"
                    onChange={(e) => handleFileChange(e, setCostSummary)}
                    className="hidden"
                  />
                </Card>
              </div>
            )}

            {/* Step 4: Additional Documents */}
            {currentStep === 4 && (
              <Card className="p-8 mb-6 border-blue-100">
                <div className="flex items-center gap-3 mb-6">
                  <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
                    <Upload className="w-6 h-6 text-blue-600" />
                  </div>
                  <div>
                    <h2 className="text-2xl font-bold text-blue-900">Additional Documents (Optional)</h2>
                    <p className="text-sm text-blue-600">Upload any supporting documents if needed</p>
                  </div>
                </div>

                <Label
                  htmlFor="additionalDocs"
                  className="flex flex-col items-center justify-center h-48 border-2 border-dashed border-blue-300 rounded-lg cursor-pointer hover:bg-blue-50 transition-colors"
                >
                  {additionalDocs.length > 0 ? (
                    <div className="text-center">
                      <CheckCircle className="w-16 h-16 text-green-600 mx-auto mb-4" />
                      <p className="text-lg text-blue-900 font-medium mb-2">
                        {additionalDocs.length} document{additionalDocs.length > 1 ? 's' : ''} uploaded
                      </p>
                      <p className="text-sm text-blue-600">Click to add more documents</p>
                    </div>
                  ) : (
                    <div className="text-center">
                      <Upload className="w-16 h-16 text-blue-400 mx-auto mb-4" />
                      <p className="text-lg text-blue-900 font-medium mb-2">
                        Click to upload Additional Documents
                      </p>
                      <p className="text-sm text-blue-600">PDF, JPG, PNG format - Multiple files allowed</p>
                    </div>
                  )}
                </Label>
                <Input
                  id="additionalDocs"
                  type="file"
                  accept=".pdf,image/*"
                  multiple
                  onChange={handleAdditionalDocsChange}
                  className="hidden"
                />

                {additionalDocs.length > 0 && (
                  <div className="mt-6">
                    <h3 className="font-semibold text-blue-900 mb-3">Uploaded Additional Documents</h3>
                    <div className="space-y-2">
                      {additionalDocs.map((doc, index) => (
                        <div
                          key={index}
                          className="flex items-center justify-between p-3 bg-blue-50 rounded-lg"
                        >
                          <div className="flex items-center gap-3">
                            <FileText className="w-5 h-5 text-blue-600" />
                            <div>
                              <p className="font-medium text-blue-900">{doc.name}</p>
                              <p className="text-xs text-blue-600">
                                {(doc.size / 1024).toFixed(2)} KB
                              </p>
                            </div>
                          </div>
                          <button
                            type="button"
                            onClick={() => removeAdditionalDoc(index)}
                            className="text-red-600 hover:text-red-700"
                          >
                            <X className="w-5 h-5" />
                          </button>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                <div className="mt-6 p-4 bg-green-50 border border-green-200 rounded-lg">
                  <h3 className="font-semibold text-green-900 mb-2">✓ Ready to Submit</h3>
                  <p className="text-sm text-green-700">
                    All required documents have been uploaded. You can add additional documents or proceed to submit.
                  </p>
                </div>
              </Card>
            )}
          </motion.div>

          {/* Navigation Buttons */}
          <div className="flex justify-between gap-4">
            <Button
              type="button"
              variant="outline"
              onClick={handleBack}
              disabled={currentStep === 1}
              className="border-blue-300 text-blue-700"
            >
              <ArrowLeft className="w-4 h-4 mr-2" />
              Back
            </Button>
            
            <div className="flex gap-4">
              <Link to="/">
                <Button type="button" variant="outline" className="border-blue-300 text-blue-700">
                  Cancel
                </Button>
              </Link>
              
              {currentStep < 4 ? (
                <Button
                  type="button"
                  onClick={handleNext}
                  className="bg-blue-600 hover:bg-blue-700 text-white px-8"
                >
                  Next Step
                  <ArrowRight className="w-4 h-4 ml-2" />
                </Button>
              ) : (
                <Button
                  type="button"
                  onClick={handleSubmit}
                  disabled={uploading}
                  className="bg-green-600 hover:bg-green-700 text-white px-8"
                >
                  {uploading ? 'Submitting...' : 'Submit for Review'}
                </Button>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}