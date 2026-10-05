import 'dart:typed_data';

/// What kind of file a vaccination record is (decision D5: images and PDF).
enum UploadKind { image, pdf }

/// A file chosen for upload, already read into memory, with its detected
/// type. Works the same on web and mobile (no dart:io).
class UploadData {
  final Uint8List bytes;
  final String name;
  final UploadKind kind;
  final String contentType;
  final String extension;

  const UploadData._(this.bytes, this.name, this.kind, this.contentType, this.extension);

  bool get isPdf => kind == UploadKind.pdf;
  int get size => bytes.length;
}

/// File-type and size checks for uploads (decision D5, Q-10). Pure, so it is
/// unit-tested. The type is decided from the file's first bytes (its
/// signature), not only the name, so a renamed file cannot slip through.
class UploadRules {
  UploadRules._();

  /// Q-10: 5 MB per file. Matches storage.rules.
  static const int maxBytes = 5 * 1024 * 1024;

  /// Offered in the "Upload file" picker.
  static const List<String> documentExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'];

  static const String typeError = 'Please choose a PDF or an image (JPG, PNG, WEBP or HEIC).';
  static const String imageOnlyError = 'Please choose an image (JPG, PNG, WEBP or HEIC).';
  static const String emptyError = 'The selected file is empty. Please choose another file.';

  static String sizeError(int bytes) =>
      'The selected file is ${formatSize(bytes)}. The limit is 5 MB — please choose a smaller file or take a clearer, smaller photo.';

  /// Detects the type from the file signature. Returns (kind, contentType, ext)
  /// or null when the bytes are not a supported image or PDF.
  static (UploadKind, String, String)? sniff(Uint8List b) {
    bool at(int offset, List<int> sig) {
      if (b.length < offset + sig.length) return false;
      for (var i = 0; i < sig.length; i++) {
        if (b[offset + i] != sig[i]) return false;
      }
      return true;
    }

    if (at(0, const [0x25, 0x50, 0x44, 0x46, 0x2D])) return (UploadKind.pdf, 'application/pdf', 'pdf'); // %PDF-
    if (at(0, const [0xFF, 0xD8, 0xFF])) return (UploadKind.image, 'image/jpeg', 'jpg');
    if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return (UploadKind.image, 'image/png', 'png');
    if (at(0, const [0x52, 0x49, 0x46, 0x46]) && at(8, const [0x57, 0x45, 0x42, 0x50])) return (UploadKind.image, 'image/webp', 'webp'); // RIFF....WEBP
    if (at(4, const [0x66, 0x74, 0x79, 0x70])) {
      // ISO-BMFF "ftyp" box: HEIC/HEIF photos from iPhones.
      final brand = b.length >= 12 ? String.fromCharCodes(b.sublist(8, 12)) : '';
      if (const ['heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1', 'heim', 'heis'].contains(brand)) return (UploadKind.image, 'image/heic', 'heic');
    }
    return null;
  }

  /// Validates and wraps a chosen file. Throws [UploadRuleException] with a
  /// plain-language message when it is empty, too large or not allowed.
  static UploadData check(Uint8List bytes, String name, {bool allowPdf = true}) {
    if (bytes.isEmpty) throw UploadRuleException(emptyError);
    final type = sniff(bytes);
    if (type == null || (!allowPdf && type.$1 == UploadKind.pdf)) {
      throw UploadRuleException(allowPdf ? typeError : imageOnlyError);
    }
    if (bytes.length > maxBytes) throw UploadRuleException(sizeError(bytes.length));
    final cleanName = name.trim().isEmpty ? 'file.${type.$3}' : name.trim();
    return UploadData._(bytes, cleanName, type.$1, type.$2, type.$3);
  }

  /// Whether a stored download URL points to a PDF (the object name ends in
  /// .pdf; Firebase URLs encode the path, so decode before checking).
  static bool isPdfUrl(String url) {
    if (url.isEmpty) return false;
    final path = Uri.decodeComponent(Uri.tryParse(url)?.path ?? url).toLowerCase();
    return path.endsWith('.pdf');
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class UploadRuleException implements Exception {
  final String message;
  UploadRuleException(this.message);
  @override
  String toString() => message;
}
