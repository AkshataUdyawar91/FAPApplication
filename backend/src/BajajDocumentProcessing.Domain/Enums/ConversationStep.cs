namespace BajajDocumentProcessing.Domain.Enums;

/// <summary>
/// Steps in the conversational submission flow
/// </summary>
public enum ConversationStep
{
    Greeting = 0,
    POSelection = 1,
    StateSelection = 2,
    InvoiceUpload = 3,
    ActivitySummaryUpload = 4,
    CostSummaryUpload = 5,
    TeamDetailsLoop = 6,
    EnquiryDumpUpload = 7,
    AdditionalDocsUpload = 8,
    FinalReview = 9,
    Submitted = 10
}
