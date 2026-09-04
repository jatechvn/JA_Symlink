// lib/modules/utils.dart
// Shared utility helper functions

import 'dart:io';
import 'package:path/path.dart' as p;

/// Format timestamp for CSV: yyyy-MM-dd_HH:mm:ss
String formatTimestamp([DateTime? dt]) {
  final now = dt ?? DateTime.now();
  return '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';
}

/// Format timestamp for display: yyyy-MM-dd HH:mm:ss
String formatTimestampDisplay([DateTime? dt]) {
  final now = dt ?? DateTime.now();
  return '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')} '
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';
}

/// Format timestamp for filenames (no colons): yyyy-MM-dd_HH-mm-ss
String formatTimestampFileName([DateTime? dt]) {
  final now = dt ?? DateTime.now();
  return '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}-'
      '${now.minute.toString().padLeft(2, '0')}-'
      '${now.second.toString().padLeft(2, '0')}';
}

/// Check if a path is a symlink (directory junction or symbolic link)
Future<bool> isSymlink(String path) async {
  try {
    return FileSystemEntity.typeSync(path, followLinks: false) ==
        FileSystemEntityType.link;
  } catch (_) {
    return false;
  }
}

/// Get symlink target path
Future<String?> getSymlinkTarget(String path) async {
  try {
    final link = Link(path);
    // Do not use Link.existsSync(): it follows the target and returns false
    // for dangling links, even though the reparse point itself still exists.
    if (FileSystemEntity.typeSync(path, followLinks: false) ==
        FileSystemEntityType.link) {
      return link.targetSync();
    }
  } catch (_) {}
  return null;
}

/// Normalize path separators for Windows
String normalizePath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return '';
  return p.windows.normalize(trimmed);
}

/// Compare Windows paths without treating a child folder as the same path.
bool pathsEqual(String first, String second) {
  final left = _pathComparisonKey(first);
  final right = _pathComparisonKey(second);
  return left.isNotEmpty && left == right;
}

/// Whether [candidate] is [parent] or is located below [parent].
bool isSameOrChildPath(String parent, String candidate) {
  final parentKey = _pathComparisonKey(parent);
  final candidateKey = _pathComparisonKey(candidate);
  if (parentKey.isEmpty || candidateKey.isEmpty) return false;
  if (parentKey == candidateKey) return true;
  final separator = parentKey.endsWith('\\') ? '' : '\\';
  return candidateKey.startsWith('$parentKey$separator');
}

String _pathComparisonKey(String path) {
  final normalized = normalizePath(path).replaceAll('/', '\\');
  if (normalized.isEmpty) return '';
  // Keep a volume root such as C:\\ intact while removing redundant trailing
  // separators from ordinary folder paths.
  if (normalized.length > 3) {
    return normalized.replaceFirst(RegExp(r'\\+$'), '').toLowerCase();
  }
  return normalized.toLowerCase();
}

/// Get file size in human-readable format
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// Copy directory recursively and report byte-level progress smoothly
Future<void> copyDirectoryWithProgress(
  String source,
  String destination, {
  required void Function(double percent, String fileName, String sizeInfo)
  onProgress,
}) async {
  final sourceDir = Directory(source);
  if (!sourceDir.existsSync()) {
    throw FileSystemException('Source directory does not exist', source);
  }

  if (pathsEqual(source, destination)) {
    throw ArgumentError('Source and destination directories must be different');
  }
  if (isSameOrChildPath(source, destination)) {
    throw ArgumentError('Destination cannot be inside the source directory');
  }

  // 1. Scan recursively to collect all files
  final allEntries = sourceDir.listSync(recursive: true, followLinks: false);
  final directories = <Directory>[];
  final files = <File>[];
  int totalBytes = 0;

  for (final entry in allEntries) {
    if (entry is Directory) {
      directories.add(entry);
    } else if (entry is File) {
      files.add(entry);
      try {
        totalBytes += entry.lengthSync();
      } catch (_) {}
    }
  }

  // Create directories before files so empty folders and folder-only trees are
  // preserved instead of disappearing during the copy.
  for (final directory in directories) {
    final relPath = p.relative(directory.path, from: source);
    Directory(p.join(destination, relPath)).createSync(recursive: true);
  }

  if (files.isEmpty) {
    // Empty directory, just recreate it
    Directory(destination).createSync(recursive: true);
    onProgress(1.0, '', '0 B / 0 B');
    return;
  }

  int copiedBytes = 0;
  final totalSizeStr = formatFileSize(totalBytes);

  for (final file in files) {
    final relPath = p.relative(file.path, from: source);
    final destPath = p.join(destination, relPath);

    // Create parent directory
    final destFile = File(destPath);
    final destParent = destFile.parent;
    if (!destParent.existsSync()) {
      destParent.createSync(recursive: true);
    }

    // Copy file in chunks to show smooth progress
    Stream<List<int>> sourceStream;
    IOSink destSink;
    try {
      sourceStream = file.openRead();
      destSink = destFile.openWrite();
    } catch (e) {
      throw FileSystemException('Failed to open file streams: $e', file.path);
    }

    final fileName = p.basename(file.path);

    try {
      await for (final chunk in sourceStream) {
        destSink.add(chunk);
        copiedBytes += chunk.length;

        // Calculate percent (avoid division by zero if totalBytes is 0)
        final percent = totalBytes > 0 ? (copiedBytes / totalBytes) : 1.0;
        final sizeInfo = '${formatFileSize(copiedBytes)} / $totalSizeStr';
        onProgress(percent.clamp(0.0, 1.0), fileName, sizeInfo);
      }
    } finally {
      await destSink.close();
    }
  }
}
