import 'package:flutter/material.dart';
import '../../domain/entities/conversation_message.dart';
import '../../domain/entities/validation_rule_result.dart';
import '../../data/models/card_data_model.dart';
import '../../data/models/validation_result_model.dart';

/// Bot message bubble with card rendering support and typing indicator.
class BotMessageBubble extends StatefulWidget {
  final ConversationMessage message;
  final void Function(String action, String? payloadJson)? onActionTap;

  const BotMessageBubble({
    super.key,
    required this.message,
    this.onActionTap,
  });

  @override
  State<BotMessageBubble> createState() => _BotMessageBubbleState();
}

class _BotMessageBubbleState extends State<BotMessageBubble> {
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showContent = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 600 ? screenWidth * 0.6 : screenWidth * 0.85;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _showContent ? _buildMessageContent(context) : _buildTypingIndicator(),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      key: const ValueKey('typing'),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(0),
          const SizedBox(width: 4),
          _buildDot(1),
          const SizedBox(width: 4),
          _buildDot(2),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 150)),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade500,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    return Container(
      key: const ValueKey('content'),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF003087),
                child: Icon(Icons.smart_toy, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    widget.message.content,
                    style: const TextStyle(color: Colors.black87, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
          if (widget.message.card != null)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 8),
              child: _buildCard(context, widget.message.card!),
            ),
          if (widget.message.error != null)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 4),
              child: Text(
                widget.message.error!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, CardData card) {
    if (card is POListCardModel) return _buildPOListCard(card);
    if (card is ValidationResultCardModel) return _buildValidationCard(card);
    if (card is TeamSummaryCardModel) return _buildTeamSummaryCard(card);
    if (card is FinalReviewCardModel) return _buildFinalReviewCard(card);
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Text('Card: ${card.type}')));
  }

  Widget _buildPOListCard(POListCardModel card) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Purchase Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ...card.purchaseOrders.map((po) {
              return InkWell(
                onTap: () => widget.onActionTap?.call('select_po', '{"poId": "${po.id}"}'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(po.poNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        '₹${po.remainingBalance.toStringAsFixed(0)} remaining',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationCard(ValidationResultCardModel card) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                card.allPassed ? Icons.check_circle : Icons.warning,
                color: card.allPassed ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('${card.documentType} Validation',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _buildCountChip('${card.passCount} passed', Colors.green),
              const SizedBox(width: 4),
              if (card.failCount > 0) _buildCountChip('${card.failCount} failed', Colors.red),
              if (card.warningCount > 0) ...[
                const SizedBox(width: 4),
                _buildCountChip('${card.warningCount} warnings', Colors.orange),
              ],
            ]),
            const SizedBox(height: 8),
            ...card.rules.map((rule) => _buildRuleRow(rule)),
          ],
        ),
      ),
    );
  }

  Widget _buildCountChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Widget _buildRuleRow(ValidationResultModel rule) {
    final passed = rule.passed;
    final severity = rule.severity;
    Color borderColor;
    IconData icon;
    if (passed) {
      borderColor = Colors.green;
      icon = Icons.check_circle_outline;
    } else if (severity == ValidationSeverity.warning) {
      borderColor = Colors.orange;
      icon = Icons.warning_amber;
    } else {
      borderColor = Colors.red;
      icon = Icons.cancel_outlined;
    }
    final displayLabel = rule.label ?? _ruleLabel(rule.ruleCode);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: borderColor, width: 3)),
        color: borderColor.withValues(alpha: 0.05),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: borderColor),
        const SizedBox(width: 8),
        Expanded(child: Text(displayLabel, style: const TextStyle(fontSize: 13))),
        if (rule.extractedValue != null)
          Text(rule.extractedValue!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ]),
    );
  }

  /// Maps rule codes to human-readable labels for chatbot display.
  static String _ruleLabel(String code) {
    const labels = {
      // Invoice
      'INV_INVOICE_NUMBER_PRESENT': 'Invoice Number',
      'INV_DATE_PRESENT': 'Invoice Date',
      'INV_AMOUNT_PRESENT': 'Invoice amount',
      'INV_AGENCY_NAME_ADDRESS': 'Agency Name & Addresses',
      'INV_VENDOR_CODE_PRESENT': 'Agency Code',
      'INV_PO_NUMBER_MATCH': 'PO Number',
      'INV_GST_NUMBER_PRESENT': 'GSTIN for State',
      'INV_GST_PERCENT_PRESENT': 'GST %',
      'INV_AMOUNT_VS_PO_BALANCE': 'Invoice amount limit',
      // Cost Summary
      'CS_PLACE_OF_SUPPLY_PRESENT': 'State/Place of Supply',
      'CS_ELEMENT_WISE_COSTS_PRESENT': 'Element wise Cost',
      'CS_TOTAL_DAYS_PRESENT': 'No of Days',
      'CS_ELEMENT_WISE_QUANTITY_PRESENT': 'Element wise Quantity',
      'CS_TOTAL_VS_INVOICE': 'Total Cost',
      'CS_ELEMENT_COST_VS_RATES': 'Element Cost limit as per State Rate',
      'CS_FIXED_COST_LIMITS': 'Fixed Cost Limit as per State Rate',
      'CS_VARIABLE_COST_LIMITS': 'Variable cost limit as per State Rate',
      // Activity
      'AS_DAYS_MATCH_COST_SUMMARY': 'Days worked matches Cost Summary',
      // Photo
      'PHOTO_DATE_VISIBLE': 'Date on Photos',
      'PHOTO_GPS_VISIBLE': 'GPS Coordinates',
      'PHOTO_BLUE_TSHIRT': 'Promoter wearning Blue T-shirt',
      'PHOTO_3W_VEHICLE': 'Branded 3 wheeler',
    };
    return labels[code] ?? code;
  }

  Widget _buildTeamSummaryCard(TeamSummaryCardModel card) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.groups, size: 20, color: Color(0xFF003087)),
              const SizedBox(width: 8),
              Text(card.teamName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const SizedBox(height: 8),
            Text('${card.dealerName}, ${card.city}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Text('${card.workingDays} working days • ${card.photoCount} photos',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalReviewCard(FinalReviewCardModel card) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.summarize, size: 20, color: Color(0xFF003087)),
              SizedBox(width: 8),
              Text('Submission Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const Divider(),
            _reviewRow('PO Number', card.poNumber),
            _reviewRow('State', card.state),
            _reviewRow('Invoice', card.invoiceStatus),
            _reviewRow('Cost Summary', card.costSummaryStatus),
            _reviewRow('Activity Summary', card.activitySummaryStatus),
            _reviewRow('Teams', '${card.teams.length}'),
            _reviewRow('Enquiry Records', '${card.enquiryRecordCount}'),
            _reviewRow('Total Amount', '₹${card.totalAmount.toStringAsFixed(0)}'),
          ],
        ),
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
