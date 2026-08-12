import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where a document/photo came from. [ImageSource] only covers camera and
/// gallery; KYC documents may also be an existing PDF on the device.
enum PickSource { camera, gallery, file }

/// Server-side multipart cap (see `others/API.md` — 5MB, enforced by the
/// backend for avatars, KYC docs and vehicle photos alike).
const int kMaxUploadBytes = 5 * 1024 * 1024;

/// Raised when a picked file exceeds [kMaxUploadBytes]. Caught by the upload
/// callers so the driver sees an actionable message instead of a server error
/// after a wasted round-trip.
class FileTooLargeException implements Exception {
  const FileTooLargeException(this.bytes);

  final int bytes;

  /// Size in MB, one decimal — for user-facing copy.
  String get sizeMb => (bytes / (1024 * 1024)).toStringAsFixed(1);

  @override
  String toString() => 'FileTooLargeException($bytes bytes)';
}

/// Raised when a file we expected to upload is no longer on disk.
///
/// KYC drafts are stored in the OS temporary directory so a failed upload can be
/// retried (even after the app is killed) — but the OS may reclaim that
/// directory at any time. Retrying then hands a dead path to
/// `MultipartFile.fromFile`, which throws a raw filesystem error the driver
/// can't act on. This gives them a clear "capture it again" instead.
class FileMissingException implements Exception {
  const FileMissingException(this.path);

  final String path;

  @override
  String toString() => 'FileMissingException($path)';
}

/// Verifies a file still exists and is within the server's size cap, throwing
/// [FileMissingException] / [FileTooLargeException] respectively.
///
/// Used by the pickers *and* by the retry/resume paths, which reuse a
/// previously-saved path and so never pass through a picker.
Future<void> assertUploadable(String path) async {
  final file = File(path);
  if (!await file.exists()) throw FileMissingException(path);
  final bytes = await file.length();
  if (bytes > kMaxUploadBytes) throw FileTooLargeException(bytes);
}

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
///
/// Every path enforces the server's [kMaxUploadBytes] cap *before* the caller
/// uploads, throwing [FileTooLargeException] rather than letting the request
/// fail server-side.
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
    final compressed = await _compress(picked.path);
    await _assertWithinCap(compressed);
    return compressed;
  }

  /// Picks a KYC document, which may be an image *or* a PDF (the backend
  /// accepts `application/pdf` for KYC only). Images go through the usual
  /// compression; a PDF is uploaded as-is — re-encoding it as JPEG would
  /// destroy it — so only the size cap applies.
  Future<String?> pickDocument(PickSource source) async {
    if (source != PickSource.file) {
      return pick(
        source == PickSource.camera ? ImageSource.camera : ImageSource.gallery,
      );
    }
    // Path-only: the file is streamed from disk by the multipart upload, so
    // there is no reason to load its bytes into memory here.
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    final path = result?.files.single.path;
    if (path == null) return null;

    // A picked image still benefits from compression; a PDF must pass through.
    if (p.extension(path).toLowerCase() == '.pdf') {
      await _assertWithinCap(path);
      return path;
    }
    final compressed = await _compress(path);
    await _assertWithinCap(compressed);
    return compressed;
  }

  Future<void> _assertWithinCap(String path) => assertUploadable(path);

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
