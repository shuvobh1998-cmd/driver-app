import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Shared Camera / Gallery chooser. Returns the picked [ImageSource], or null
/// if the sheet was dismissed. Used wherever a single image is captured (avatar,
/// vehicle photo).
Future<ImageSource?> showImageSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

/// Picks an image (camera or gallery) and compresses it to the shared upload
/// budget: ≤1024px on the long edge, JPEG quality 80. Returns the compressed
/// file's path, or null if the user cancelled. Reused by KYC/vehicle in D2.
class ImagePickService {
  ImagePickService([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<String?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 90,
    );
    if (picked == null) return null;
    return _compress(picked.path);
  }

  Future<String> _compress(String srcPath) async {
    final dir = await getTemporaryDirectory();
    final target = p.join(
      dir.path,
      'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final result = await FlutterImageCompress.compressAndGetFile(
      srcPath,
      target,
      quality: 80,
      minWidth: 1024,
      minHeight: 1024,
      format: CompressFormat.jpeg,
    );
    // If compression is unavailable, fall back to the original file.
    return result?.path ?? srcPath;
  }
}
