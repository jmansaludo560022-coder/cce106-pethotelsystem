import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';
import 'camera_capture_screen.dart';
import 'common.dart';

/// An image chosen through [showPhotoSourceSheet] (already compressed).
class PickedPhoto {
  final XFile file;
  final Uint8List bytes;
  const PickedPhoto(this.file, this.bytes);
}

/// Result of the sheet: a new photo, or a request to remove the current one.
class PhotoSheetResult {
  final PickedPhoto? photo;
  final bool removed;
  const PhotoSheetResult._(this.photo, this.removed);
  const PhotoSheetResult.picked(PickedPhoto p) : this._(p, false);
  const PhotoSheetResult.removed() : this._(null, true);
}

/// Native camera through image_picker: Android and iOS.
bool get _nativeCamera =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// "Take photo" is offered on the project's targets: Android and iOS (native
/// camera app via image_picker) and Flutter Web (in-app webcam via the
/// `camera` package, decision D4). image_picker alone cannot open a webcam on
/// web — it silently showed the file chooser (spec bug §11.2). Desktop is not
/// a project target, so the option is shown disabled there.
bool get cameraSupported => kIsWeb || _nativeCamera;

/// Spec §11.2: one shared sheet — Take photo / Choose from gallery / Remove —
/// used for the pet photo, the vaccination record and the room photo, so all
/// of them behave the same. Images are compressed (spec §11.1: quality 70,
/// max 1080 px) before they are returned.
Future<PhotoSheetResult?> showPhotoSourceSheet(
  BuildContext context, {
  String title = 'Add a photo',
  bool allowRemove = false,
}) async {
  final source = await showModalBottomSheet<Object>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Align(alignment: Alignment.centerLeft, child: Text(title, style: Theme.of(ctx).textTheme.titleMedium)),
        ),
        if (cameraSupported)
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
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
          subtitle: kIsWeb ? const Text('Pick a photo from your files') : null,
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
        if (allowRemove)
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            title: const Text('Remove photo', style: TextStyle(color: AppColors.errorText)),
            onTap: () => Navigator.pop(ctx, 'remove'),
          ),
      ]),
    ),
  );
  if (source == null || !context.mounted) return null;
  if (source == 'remove') return const PhotoSheetResult.removed();
  final picked = await pickCompressedPhoto(context, source as ImageSource);
  return picked == null ? null : PhotoSheetResult.picked(picked);
}

/// Opens the camera for this platform: the webcam screen on web, the native
/// camera app on Android/iOS. On web, "Choose a file instead" (shown when the
/// camera is unavailable or denied) falls back to the file chooser.
Future<PickedPhoto?> _takePhoto(BuildContext context) async {
  if (!kIsWeb) return _pickWithImagePicker(context, ImageSource.camera);
  final r = await Navigator.of(context).push<CameraCaptureResult>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const CameraCaptureScreen()),
  );
  if (r == null || !context.mounted) return null;
  if (r.useFileInstead) return _pickWithImagePicker(context, ImageSource.gallery);
  return PickedPhoto(r.file!, r.bytes!);
}

/// Picks one image from [source], compressed, with friendly error messages.
/// [ImageSource.camera] always opens a real camera (never a file chooser).
Future<PickedPhoto?> pickCompressedPhoto(BuildContext context, ImageSource source) {
  if (source == ImageSource.camera) return _takePhoto(context);
  return _pickWithImagePicker(context, source);
}

Future<PickedPhoto?> _pickWithImagePicker(BuildContext context, ImageSource source) async {
  try {
    final f = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1080, maxHeight: 1080);
    if (f == null) return null;
    return PickedPhoto(f, await f.readAsBytes());
  } on PlatformException catch (e) {
    if (!context.mounted) return null;
    final denied = e.code.contains('access_denied') || e.code.contains('permission');
    if (denied) {
      showError(
        context,
        source == ImageSource.camera
            ? 'Camera access is turned off. Allow camera access for Pet Hotel in your phone Settings, then try again.'
            : 'Photo access is turned off. Allow photo access for Pet Hotel in your phone Settings, then try again.',
      );
    } else {
      showError(context, source == ImageSource.camera ? 'The camera could not be opened on this device.' : 'The photo could not be opened.');
    }
    return null;
  } catch (_) {
    if (context.mounted) showError(context, 'The photo could not be opened. Please try another image.');
    return null;
  }
}
