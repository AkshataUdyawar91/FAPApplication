import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// Card prompting the user to upload a file with allowed format badges.
class FileUploadCard extends StatefulWidget {
  final String label;
  final List<String> allowedFormats;
  final void Function(Uint8List bytes, String fileName) onFileSelected;
  final bool isUploading;

  const FileUploadCard({
    super.key,
    required this.label,
    required this.allowedFormats,
    required this.onFileSelected,
    this.isUploading = false,
  });

  @override
  State<FileUploadCard> createState() => _FileUploadCardState();
}

class _FileUploadCardState extends State<FileUploadCard> {
  String? _selectedFileName;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _mapExtensions(widget.allowedFormats),
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      setState(() => _selectedFileName = file.name);
      widget.onFileSelected(file.bytes!, file.name);
    }
  }

  List<String> _mapExtensions(List<String> formats) {
    final exts = <String>[];
    for (final f in formats) {
      switch (f.toUpperCase()) {
        case 'PDF':
          exts.add('pdf');
          break;
        case 'WORD':
          exts.addAll(['doc', 'docx']);
          break;
        case 'JPG':
          exts.addAll(['jpg', 'jpeg']);
          break;
        case 'PNG':
          exts.add('png');
          break;
      }
    }
    return exts;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            // Format badges
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: widget.allowedFormats.map((f) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Upload area
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: widget.isUploading ? null : _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.blue.shade200,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.blue.shade50.withValues(alpha: 0.3),
                ),
                child: Column(
                  children: [
                    if (widget.isUploading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 32,
                        color: Colors.blue.shade400,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFileName ?? 'Tap to select file',
                      style: TextStyle(
                        fontSize: 13,
                        color: _selectedFileName != null
                            ? Colors.black87
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
