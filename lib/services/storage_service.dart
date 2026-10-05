import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../core/utils/upload_rules.dart';

/// Firebase Storage uploads (vaccination records as image or PDF, pet and room photos).
///
/// Spec §11.1 fix: uploads used to have no timeout, and Firebase retries a
/// failing upload for up to 10 minutes by default — so a missing bucket or a
/// bad connection showed as an endless spinner. Now each upload is limited to
/// [uploadTimeout], the SDK retry window is shortened, and failures become
/// plain-language [UploadException]s the UI can show with a Retry button.
class StorageService {
  FirebaseStorage get _storage => FirebaseStorage.instance;

  /// Q-10: maximum 5 MB (images are also compressed when picked).
  static const int maxBytes = UploadRules.maxBytes;
  static const Duration uploadTimeout = Duration(seconds: 30);
  static bool _retryConfigured = false;

  void _configureRetry() {
    if (_retryConfigured) return;
    _retryConfigured = true;
    try {
      _storage.setMaxUploadRetryTime(const Duration(seconds: 20));
      _storage.setMaxOperationRetryTime(const Duration(seconds: 20));
    } catch (_) {
      // Not supported on every platform — the explicit timeout below still applies.
    }
  }

  /// Uploads an image [file] as `<folder>/<fileName>.<ext>` and returns its
  /// download URL. The type is checked from the file's bytes (images only).
  Future<String> uploadImage(XFile file, String folder, {String fileName = 'image'}) async {
    final UploadData data;
    try {
      data = UploadRules.check(await file.readAsBytes(), file.name, allowPdf: false);
    } on UploadRuleException catch (e) {
      throw UploadException(e.message);
    }
    return uploadData(data, folder, fileName: fileName);
  }

  /// Uploads an already-checked file (image or PDF, decision D5) as
  /// `<folder>/<fileName>.<ext>` and returns its download URL.
  /// A fixed [fileName] means a retry overwrites the same object instead of
  /// leaving orphan copies. Works on mobile and web (uses bytes, not dart:io).
  Future<String> uploadData(UploadData data, String folder, {String fileName = 'file'}) async {
    _configureRetry();
    if (data.size > maxBytes) throw UploadException(UploadRules.sizeError(data.size));
    final ref = _storage.ref('$folder/$fileName.${data.extension}');
    final task = ref.putData(data.bytes, SettableMetadata(contentType: data.contentType));
    try {
      await task.timeout(uploadTimeout, onTimeout: () async {
        await task.cancel();
        throw UploadException('The upload took too long. Check your internet connection and tap Retry.');
      });
      return await ref.getDownloadURL().timeout(const Duration(seconds: 15));
    } on UploadException {
      rethrow;
    } on TimeoutException {
      throw UploadException('The upload took too long. Check your internet connection and tap Retry.');
    } on FirebaseException catch (e) {
      throw UploadException(_messageFor(e));
    }
  }

  static String _messageFor(FirebaseException e) {
    final text = '${e.code} ${e.message ?? ''}'.toLowerCase();
    if (e.code == 'bucket-not-found' || e.code == 'project-not-found' || text.contains('404') || text.contains('not found')) {
      return 'Photo storage is not set up on the server yet, so files cannot be uploaded. Please contact the hotel.';
    }
    if (e.code == 'unauthorized' || e.code == 'unauthenticated' || text.contains('403')) {
      return 'You are not allowed to upload this file. Please sign in again or contact the hotel.';
    }
    if (e.code == 'canceled') return 'The upload was cancelled. Tap Retry to try again.';
    if (e.code == 'retry-limit-exceeded' || text.contains('network')) {
      return 'The upload failed because of a connection problem. Check your internet and tap Retry.';
    }
    if (e.code == 'quota-exceeded') return 'The hotel\'s storage quota is full. Please contact the hotel.';
    return 'The file could not be uploaded (${e.code}). Tap Retry to try again.';
  }
}

class UploadException implements Exception {
  final String message;
  UploadException(this.message);
  @override
  String toString() => message;
}
