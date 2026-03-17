import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/submission_providers.dart';
import '../providers/submission_notifier.dart';
import '../widgets/document_upload_card.dart';

class DocumentUploadPage extends ConsumerWidget {
  const DocumentUploadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionState = ref.watch(submissionNotifierProvider);

    ref.listen<SubmissionState>(submissionNotifierProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
          ),
        );
      }

      if (next.currentSubmission != null && !next.isSubmitting) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documents submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Documents'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;
          final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 900;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 24 : (isTablet ? 20 : 16)),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 800 : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Required documents section
                    Text(
                      'Required Documents',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // PO Document
                    DocumentUploadCard(
                      title: 'Purchase Order (PO)',
                      subtitle: 'PDF format, max 10MB',
                      file: submissionState.poFile,
                      onRemove: () => ref.read(submissionNotifierProvider.notifier).setPOFile(null),
                      onFilePicked: (file) =>
                          ref.read(submissionNotifierProvider.notifier).setPOFile(file),
                      allowedExtensions: const ['pdf'],
                      icon: Icons.description,
                    ),
                    const SizedBox(height: 12),

                    // Invoice Document
                    DocumentUploadCard(
                      title: 'Invoice',
                      subtitle: 'PDF format, max 10MB',
                      file: submissionState.invoiceFile,
                      onRemove: () =>
                          ref.read(submissionNotifierProvider.notifier).setInvoiceFile(null),
                      onFilePicked: (file) =>
                          ref.read(submissionNotifierProvider.notifier).setInvoiceFile(file),
                      allowedExtensions: const ['pdf'],
                      icon: Icons.receipt_long,
                    ),
                    const SizedBox(height: 12),

                    // Cost Summary Document
                    DocumentUploadCard(
                      title: 'Cost Summary',
                      subtitle: 'PDF format, max 10MB',
                      file: submissionState.costSummaryFile,
                      onRemove: () =>
                          ref.read(submissionNotifierProvider.notifier).setCostSummaryFile(null),
                      onFilePicked: (file) =>
                          ref.read(submissionNotifierProvider.notifier).setCostSummaryFile(file),
                      allowedExtensions: const ['pdf'],
                      icon: Icons.attach_money,
                    ),
                    const SizedBox(height: 24),

                    // Photos section
                    Text(
                      'Activity Photos (${submissionState.photoFiles.length}/20)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // Add photo button
                    if (submissionState.photoFiles.length < 20)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final image = await picker.pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            ref
                                .read(submissionNotifierProvider.notifier)
                                .addPhotoFile(File(image.path));
                          }
                        },
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Add Photo'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Photo list
                    if (submissionState.photoFiles.isNotEmpty)
                      ...List.generate(
                        submissionState.photoFiles.length,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Card(
                            child: ListTile(
                              leading: const Icon(Icons.image, color: Color(0xFF003087)),
                              title: Text(
                                submissionState.photoFiles[index].path.split('/').last,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${(submissionState.photoFiles[index].lengthSync() / 1024).toStringAsFixed(1)} KB',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => ref
                                    .read(submissionNotifierProvider.notifier)
                                    .removePhotoFile(index),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Submit button
                    ElevatedButton(
                      onPressed: submissionState.canSubmit && !submissionState.isSubmitting
                          ? () => ref.read(submissionNotifierProvider.notifier).submitDocuments()
                          : null,
                      child: submissionState.isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Submit Documents'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
