import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';
import '../constants/app_tokens.dart';
import '../utils/upload_rules.dart';
import 'common.dart';
import 'custom_button.dart';
import 'custom_card.dart';
import 'photo_source_sheet.dart';

/// Result of [showDocumentSourceSheet]: a checked file, or "remove".
class DocumentSheetResult {
  final UploadData? file;
  final bool removed;
  const DocumentSheetResult._(this.file, this.removed);
  const DocumentSheetResult.picked(UploadData f) : this._(f, false);
  const DocumentSheetResult.removed() : this._(null, true);
}

/// Source of the vaccination record (decision D5).
enum DocumentSource { camera, gallery, file, remove }

/// Decision D5: the vaccination record can be a photo or a PDF, with three
/// distinct actions — Take photo (real camera), Choose from gallery (photos
/// only) and Upload file (PDF or image from Files / Drive / downloads).
/// Every choice is checked for type and size before it is accepted.
Future<DocumentSheetResult?> showDocumentSourceSheet(BuildContext context, {String title = 'Vaccination record', bool allowRemove = false}) async {
  final source = await showModalBottomSheet<DocumentSource>(
    context: context,
    builder: (ctx) => DocumentSourceOptions(title: title, allowRemove: allowRemove),
  );
  if (source == null || !context.mounted) return null;
  if (source == DocumentSource.remove) return const DocumentSheetResult.removed();

  try {
    if (source == DocumentSource.file) {
      final picked = await DocumentPicker.pick();
      if (picked == null) return null; // cancelled
      return DocumentSheetResult.picked(UploadRules.check(picked.$1, picked.$2));
    }
    if (!context.mounted) return null;
    final photo = await pickCompressedPhoto(context, source == DocumentSource.camera ? ImageSource.camera : ImageSource.gallery);
    if (photo == null) return null; // cancelled, or the picker already showed an error
    return DocumentSheetResult.picked(UploadRules.check(photo.bytes, photo.file.name, allowPdf: false));
  } on UploadRuleException catch (e) {
    if (context.mounted) showError(context, e.message);
    return null;
  }
}

/// The sheet's options (public so it can be tested on its own).
class DocumentSourceOptions extends StatelessWidget {
  final String title;
  final bool allowRemove;
  const DocumentSourceOptions({super.key, required this.title, this.allowRemove = false});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.sm),
            child: Align(alignment: Alignment.centerLeft, child: Text(title, style: AppTextStyles.titleMedium)),
          ),
          if (cameraSupported)
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              subtitle: const Text('Use the camera'),
              onTap: () => Navigator.pop(context, DocumentSource.camera),
            )
          else
            const ListTile(
              enabled: false,
              leading: Icon(Icons.no_photography_outlined),
              title: Text('Take photo'),
              subtitle: Text('Camera capture is available on the web and mobile apps.'),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            subtitle: const Text('A photo of the certificate'),
            onTap: () => Navigator.pop(context, DocumentSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_rounded),
            title: const Text('Upload file'),
            subtitle: const Text('PDF or image, up to 5 MB'),
            onTap: () => Navigator.pop(context, DocumentSource.file),
          ),
          if (allowRemove)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Remove file', style: TextStyle(color: AppColors.errorText)),
              onTap: () => Navigator.pop(context, DocumentSource.remove),
            ),
        ]),
      );
}

/// Opens the system file picker for a PDF or image. Returns (bytes, name),
/// or null when cancelled. Large files are rejected before being read fully.
class DocumentPicker {
  DocumentPicker._();

  /// Tests replace this to avoid the platform picker.
  @visibleForTesting
  static Future<(Uint8List, String)?> Function()? debugOverride;

  static Future<(Uint8List, String)?> pick() async {
    if (debugOverride != null) return debugOverride!();
    final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: UploadRules.documentExtensions);
    } on PlatformException {
      throw UploadRuleException('The file chooser could not be opened on this device.');
    }
    if (files.isEmpty) return null;
    final f = files.first;
    final length = await f.length();
    if (length != null && length > UploadRules.maxBytes) throw UploadRuleException(UploadRules.sizeError(length));
    return (await f.xFile.readAsBytes(), f.name);
  }
}

/// Shows the chosen or saved vaccination record: an image preview, or a PDF
/// indicator (decision D5), with Remove and Replace.
class VaccinationFileTile extends StatelessWidget {
  final UploadData? newFile;
  final String existingUrl;
  final bool previewOpen;
  final bool enabled;
  final VoidCallback onTogglePreview;
  final VoidCallback onRemove;
  final VoidCallback onReplace;

  const VaccinationFileTile({
    super.key,
    this.newFile,
    this.existingUrl = '',
    this.previewOpen = true,
    this.enabled = true,
    required this.onTogglePreview,
    required this.onRemove,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    final f = newFile;
    final isPdf = f != null ? f.isPdf : UploadRules.isPdfUrl(existingUrl);
    final title = f != null ? f.name : (isPdf ? 'PDF on file' : 'Record on file');
    final subtitle = f != null ? '${isPdf ? 'PDF document' : 'Image'} · ${UploadRules.formatSize(f.size)}' : 'Saved with this pet';
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPdf ? AppColors.berrySoft : AppColors.tealSoft,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: AppColors.ink, width: AppBorders.width),
            ),
            child: Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded, color: AppColors.ink),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTextStyles.labelLargeRole, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(subtitle, style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted)),
            ]),
          ),
          if (!isPdf)
            IconButton(
              tooltip: previewOpen ? 'Hide preview' : 'Show preview',
              icon: Icon(previewOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              onPressed: onTogglePreview,
            ),
          IconButton(
            tooltip: 'Remove file',
            icon: const Icon(Icons.close_rounded, color: AppColors.error),
            onPressed: enabled ? onRemove : null,
          ),
        ]),
        if (!isPdf && previewOpen) ...[
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: f != null
                ? Image.memory(f.bytes, height: 220, width: double.infinity, fit: BoxFit.contain)
                : AppImage(url: existingUrl, height: 220, width: double.infinity, fit: BoxFit.contain, fallbackIcon: Icons.description_outlined),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        TertiaryButton(label: 'Choose a different file', icon: Icons.swap_horiz_rounded, onPressed: enabled ? onReplace : null),
      ]),
    );
  }
}
