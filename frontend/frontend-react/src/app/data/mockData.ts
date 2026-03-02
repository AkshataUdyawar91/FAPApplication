// Mock data store for documents
export interface Document {
  id: string;
  agencyName: string;
  submittedDate: string;
  status: 'pending' | 'ai-processing' | 'asm-review' | 'approved' | 'rejected';
  documents: {
    purchaseOrder?: File | string;
    invoice?: File | string;
    costSummary?: File | string;
    photos: (File | string)[];
  };
  aiAnalysis?: {
    confidence: number;
    poValidation: {
      status: 'valid' | 'invalid' | 'warning';
      poNumber: string;
      amount: number;
      date: string;
      issues?: string[];
    };
    invoiceValidation: {
      status: 'valid' | 'invalid' | 'warning';
      invoiceNumber: string;
      amount: number;
      date: string;
      matchesPO: boolean;
      issues?: string[];
    };
    costSummaryValidation: {
      status: 'valid' | 'invalid' | 'warning';
      totalAmount: number;
      matchesInvoice: boolean;
      breakdown: { item: string; amount: number }[];
      issues?: string[];
    };
    photoValidation: {
      status: 'valid' | 'invalid' | 'warning';
      photoCount: number;
      qualityScore: number;
      issues?: string[];
    };
    recommendation: 'approve' | 'reject' | 'review';
    flags: string[];
  };
  asmDecision?: {
    action: 'approved' | 'rejected';
    comments: string;
    date: string;
    officer: string;
  };
  amount: number;
}

// Mock documents data
export const mockDocuments: Document[] = [
  {
    id: 'DOC001',
    agencyName: 'Creative Marketing Solutions',
    submittedDate: '2026-03-01T10:30:00',
    status: 'asm-review',
    amount: 45000,
    documents: {
      purchaseOrder: 'po_001.pdf',
      invoice: 'invoice_001.pdf',
      costSummary: 'cost_001.pdf',
      photos: ['photo1.jpg', 'photo2.jpg', 'photo3.jpg']
    },
    aiAnalysis: {
      confidence: 94,
      poValidation: {
        status: 'valid',
        poNumber: 'PO-2026-0234',
        amount: 45000,
        date: '2026-02-15'
      },
      invoiceValidation: {
        status: 'valid',
        invoiceNumber: 'INV-2026-0891',
        amount: 45000,
        date: '2026-02-28',
        matchesPO: true
      },
      costSummaryValidation: {
        status: 'valid',
        totalAmount: 45000,
        matchesInvoice: true,
        breakdown: [
          { item: 'Outdoor Advertising', amount: 30000 },
          { item: 'Print Materials', amount: 10000 },
          { item: 'Installation', amount: 5000 }
        ]
      },
      photoValidation: {
        status: 'valid',
        photoCount: 3,
        qualityScore: 92
      },
      recommendation: 'approve',
      flags: []
    }
  },
  {
    id: 'DOC002',
    agencyName: 'Digital Wave Agency',
    submittedDate: '2026-03-01T14:15:00',
    status: 'asm-review',
    amount: 78500,
    documents: {
      purchaseOrder: 'po_002.pdf',
      invoice: 'invoice_002.pdf',
      costSummary: 'cost_002.pdf',
      photos: ['photo1.jpg', 'photo2.jpg']
    },
    aiAnalysis: {
      confidence: 67,
      poValidation: {
        status: 'valid',
        poNumber: 'PO-2026-0235',
        amount: 75000,
        date: '2026-02-20'
      },
      invoiceValidation: {
        status: 'warning',
        invoiceNumber: 'INV-2026-0892',
        amount: 78500,
        date: '2026-02-28',
        matchesPO: false,
        issues: ['Amount exceeds PO by ₹3,500']
      },
      costSummaryValidation: {
        status: 'warning',
        totalAmount: 78500,
        matchesInvoice: true,
        breakdown: [
          { item: 'Digital Campaigns', amount: 50000 },
          { item: 'Content Creation', amount: 20000 },
          { item: 'Additional Services', amount: 8500 }
        ],
        issues: ['Additional charges not in original PO']
      },
      photoValidation: {
        status: 'warning',
        photoCount: 2,
        qualityScore: 68,
        issues: ['Fewer photos than expected', 'Image quality below standard']
      },
      recommendation: 'review',
      flags: ['Amount Mismatch', 'Quality Issues']
    }
  },
  {
    id: 'DOC003',
    agencyName: 'Metro Advertising Co.',
    submittedDate: '2026-03-02T09:00:00',
    status: 'approved',
    amount: 120000,
    documents: {
      purchaseOrder: 'po_003.pdf',
      invoice: 'invoice_003.pdf',
      costSummary: 'cost_003.pdf',
      photos: ['photo1.jpg', 'photo2.jpg', 'photo3.jpg', 'photo4.jpg']
    },
    aiAnalysis: {
      confidence: 98,
      poValidation: {
        status: 'valid',
        poNumber: 'PO-2026-0236',
        amount: 120000,
        date: '2026-02-10'
      },
      invoiceValidation: {
        status: 'valid',
        invoiceNumber: 'INV-2026-0893',
        amount: 120000,
        date: '2026-02-27',
        matchesPO: true
      },
      costSummaryValidation: {
        status: 'valid',
        totalAmount: 120000,
        matchesInvoice: true,
        breakdown: [
          { item: 'Billboard Campaign', amount: 80000 },
          { item: 'Transit Advertising', amount: 30000 },
          { item: 'Maintenance', amount: 10000 }
        ]
      },
      photoValidation: {
        status: 'valid',
        photoCount: 4,
        qualityScore: 95
      },
      recommendation: 'approve',
      flags: []
    },
    asmDecision: {
      action: 'approved',
      comments: 'All documents verified. Campaign execution quality is excellent.',
      date: '2026-03-02T11:30:00',
      officer: 'Rajesh Kumar (ASM-North)'
    }
  },
  {
    id: 'DOC004',
    agencyName: 'Brand Boosters',
    submittedDate: '2026-02-28T16:45:00',
    status: 'rejected',
    amount: 55000,
    documents: {
      purchaseOrder: 'po_004.pdf',
      invoice: 'invoice_004.pdf',
      costSummary: 'cost_004.pdf',
      photos: ['photo1.jpg']
    },
    aiAnalysis: {
      confidence: 45,
      poValidation: {
        status: 'invalid',
        poNumber: 'PO-2026-0198',
        amount: 50000,
        date: '2026-01-15',
        issues: ['PO expired', 'Original PO was cancelled']
      },
      invoiceValidation: {
        status: 'invalid',
        invoiceNumber: 'INV-2026-0890',
        amount: 55000,
        date: '2026-02-25',
        matchesPO: false,
        issues: ['Invoice amount exceeds PO', 'Invoice date before work completion']
      },
      costSummaryValidation: {
        status: 'invalid',
        totalAmount: 55000,
        matchesInvoice: true,
        breakdown: [
          { item: 'Campaign Materials', amount: 55000 }
        ],
        issues: ['Insufficient breakdown detail', 'Missing itemization']
      },
      photoValidation: {
        status: 'invalid',
        photoCount: 1,
        qualityScore: 42,
        issues: ['Insufficient photographic evidence', 'Poor image quality', 'Missing mandatory photos']
      },
      recommendation: 'reject',
      flags: ['Expired PO', 'Insufficient Documentation', 'Quality Issues']
    },
    asmDecision: {
      action: 'rejected',
      comments: 'Cannot process due to cancelled PO and insufficient documentation. Please resubmit with valid PO.',
      date: '2026-03-01T10:15:00',
      officer: 'Priya Sharma (ASM-West)'
    }
  },
  {
    id: 'DOC005',
    agencyName: 'Sunrise Media Group',
    submittedDate: '2026-03-02T11:20:00',
    status: 'ai-processing',
    amount: 92000,
    documents: {
      purchaseOrder: 'po_005.pdf',
      invoice: 'invoice_005.pdf',
      costSummary: 'cost_005.pdf',
      photos: ['photo1.jpg', 'photo2.jpg', 'photo3.jpg']
    }
  }
];

// Analytics data
export const analyticsData = {
  overview: {
    totalSubmissions: 248,
    pending: 12,
    approved: 198,
    rejected: 38,
    totalAmount: 18500000,
    approvedAmount: 15200000
  },
  monthlyTrends: [
    { month: 'Sep', submissions: 38, approved: 32, rejected: 6, amount: 2800000 },
    { month: 'Oct', submissions: 42, approved: 35, rejected: 7, amount: 3100000 },
    { month: 'Nov', submissions: 45, approved: 38, rejected: 7, amount: 3400000 },
    { month: 'Dec', submissions: 51, approved: 40, rejected: 11, amount: 3800000 },
    { month: 'Jan', submissions: 38, approved: 30, rejected: 8, amount: 2900000 },
    { month: 'Feb', submissions: 34, approved: 23, rejected: 11, amount: 2500000 }
  ],
  aiPerformance: {
    averageConfidence: 82,
    accuracyRate: 94,
    processingTime: '2.3 min',
    flaggedForReview: 18
  },
  topAgencies: [
    { name: 'Creative Marketing Solutions', submissions: 42, approved: 40, amount: 3200000 },
    { name: 'Metro Advertising Co.', submissions: 38, approved: 36, amount: 2900000 },
    { name: 'Digital Wave Agency', submissions: 35, approved: 32, amount: 2600000 },
    { name: 'Brand Boosters', submissions: 28, approved: 20, amount: 1800000 },
    { name: 'Sunrise Media Group', submissions: 25, approved: 23, amount: 1900000 }
  ],
  issueBreakdown: [
    { issue: 'Amount Mismatch', count: 15 },
    { issue: 'Missing Documents', count: 12 },
    { issue: 'Quality Issues', count: 8 },
    { issue: 'Expired PO', count: 6 },
    { issue: 'Date Discrepancies', count: 5 }
  ]
};
