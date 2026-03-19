import 'package:flutter/material.dart';
import '_admin_placeholder.dart';

class EnquiryDumpPage extends StatelessWidget {
  final String token;
  const EnquiryDumpPage({super.key, required this.token});

  @override
  Widget build(BuildContext context) =>
      const AdminPlaceholder(title: 'Complete Enquiry Dump per FAP', icon: Icons.download_outlined);
}
