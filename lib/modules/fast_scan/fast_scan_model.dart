// lib/modules/fast_scan/fast_scan_model.dart
// Data models for ultra-fast MFT / USN disk scanning results

import 'package:flutter/foundation.dart';

/// Representation of a folder discovered during high-speed disk scanning
@immutable
class FastFolderNode {
  final String path;
  final int sizeBytes;
  final int fileCount;
  final int folderCount;
  final String driveLetter;

  const FastFolderNode({
    required this.path,
    required this.sizeBytes,
    required this.fileCount,
    this.folderCount = 0,
    required this.driveLetter,
  });

  /// Human readable formatted size (B, KB, MB, GB, TB)
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeBytes < 1024 * 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(2)} TB';
  }

  /// Folder name extracted from path
  String get folderName {
    final normalized = path.replaceAll('/', '\\');
    final parts = normalized.split('\\').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return path;
    return parts.last;
  }

  /// Convert from JSON map received from native engine or CLI
  factory FastFolderNode.fromJson(Map<String, dynamic> json, String drive) {
    return FastFolderNode(
      path: json['path'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      fileCount: (json['file_count'] as num?)?.toInt() ?? 0,
      folderCount: (json['folder_count'] as num?)?.toInt() ?? 0,
      driveLetter: drive,
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'size_bytes': sizeBytes,
    'file_count': fileCount,
    'folder_count': folderCount,
    'drive_letter': driveLetter,
  };

  @override
  String toString() =>
      'FastFolderNode(path: $path, size: $formattedSize, files: $fileCount)';
}

/// Comprehensive summary of a complete drive scan session
@immutable
class DriveScanResult {
  final String driveLetter;
  final int durationMs;
  final int totalFilesScanned;
  final int totalDirectoriesScanned;
  final int totalSizeBytes;
  final List<FastFolderNode> topHeavyFolders;
  final List<FastFolderNode> rootFolders;
  final bool isMftEngine;
  final bool success;
  final String? errorMessage;
  final DateTime scannedAt;

  const DriveScanResult({
    required this.driveLetter,
    required this.durationMs,
    required this.totalFilesScanned,
    required this.totalDirectoriesScanned,
    required this.totalSizeBytes,
    required this.topHeavyFolders,
    this.rootFolders = const [],
    required this.isMftEngine,
    this.success = true,
    this.errorMessage,
    required this.scannedAt,
  });

  /// Formatted duration in seconds or ms
  String get formattedDuration {
    if (durationMs < 1000) return '$durationMs ms';
    return '${(durationMs / 1000).toStringAsFixed(2)} s';
  }

  /// Formatted total scanned data size
  String get formattedTotalSize {
    if (totalSizeBytes < 1024 * 1024 * 1024) {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Build the top-level tree node for hierarchical Tree View
  FolderTreeNode buildRootTreeNode() {
    final cleanDrive = driveLetter
        .replaceAll(':', '')
        .replaceAll('\\', '')
        .replaceAll('/', '')
        .toUpperCase();
    final effectiveRoots = rootFolders.isNotEmpty
        ? rootFolders
        : topHeavyFolders;

    final children = effectiveRoots.map((f) {
      return FolderTreeNode(
        path: f.path,
        name: f.folderName,
        sizeBytes: f.sizeBytes,
        fileCount: f.fileCount,
        folderCount: f.folderCount,
        driveLetter: cleanDrive,
        depth: 1,
        hasChildren: true,
      );
    }).toList();

    return FolderTreeNode(
      path: '$cleanDrive:\\',
      name: '$cleanDrive: (Local Disk)',
      sizeBytes: totalSizeBytes,
      fileCount: totalFilesScanned,
      folderCount: totalDirectoriesScanned,
      driveLetter: cleanDrive,
      depth: 0,
      hasChildren: true,
      isExpanded: true,
      children: children,
    );
  }

  /// Empty / initial state
  static DriveScanResult empty(String drive) => DriveScanResult(
    driveLetter: drive,
    durationMs: 0,
    totalFilesScanned: 0,
    totalDirectoriesScanned: 0,
    totalSizeBytes: 0,
    topHeavyFolders: const [],
    rootFolders: const [],
    isMftEngine: false,
    success: true,
    scannedAt: DateTime.now(),
  );

  /// Error state
  static DriveScanResult failure(String drive, String error) => DriveScanResult(
    driveLetter: drive,
    durationMs: 0,
    totalFilesScanned: 0,
    totalDirectoriesScanned: 0,
    totalSizeBytes: 0,
    topHeavyFolders: const [],
    rootFolders: const [],
    isMftEngine: false,
    success: false,
    errorMessage: error,
    scannedAt: DateTime.now(),
  );

  factory DriveScanResult.fromJson(Map<String, dynamic> json, String drive) {
    final foldersRaw = json['top_folders'] as List<dynamic>? ?? const [];
    final folders = foldersRaw
        .map((f) => FastFolderNode.fromJson(f as Map<String, dynamic>, drive))
        .toList();

    final rootRaw = json['root_folders'] as List<dynamic>? ?? const [];
    final rootList = rootRaw
        .map((f) => FastFolderNode.fromJson(f as Map<String, dynamic>, drive))
        .toList();

    return DriveScanResult(
      driveLetter: drive,
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      totalFilesScanned: (json['total_files'] as num?)?.toInt() ?? 0,
      totalDirectoriesScanned:
          (json['total_directories'] as num?)?.toInt() ?? 0,
      totalSizeBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
      topHeavyFolders: folders,
      rootFolders: rootList.isNotEmpty ? rootList : folders,
      isMftEngine: json['is_mft'] as bool? ?? false,
      success: json['success'] as bool? ?? true,
      errorMessage: json['error'] as String?,
      scannedAt: DateTime.now(),
    );
  }
}

/// Interactive tree node representing a folder in the hierarchical Tree View
class FolderTreeNode {
  final String path;
  final String name;
  final int sizeBytes;
  final int fileCount;
  final int folderCount;
  final String driveLetter;
  final int depth;
  final bool hasChildren;
  final bool isDirectFiles;
  List<FolderTreeNode> children;
  bool isExpanded;
  bool isLoading;

  FolderTreeNode({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.fileCount,
    this.folderCount = 0,
    required this.driveLetter,
    this.depth = 0,
    this.hasChildren = true,
    this.isDirectFiles = false,
    List<FolderTreeNode>? children,
    this.isExpanded = false,
    this.isLoading = false,
  }) : children = children ?? [];

  /// Human readable formatted size (B, KB, MB, GB, TB)
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeBytes < 1024 * 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(2)} TB';
  }

  factory FolderTreeNode.fromJson(
    Map<String, dynamic> json, {
    required String drive,
    int depth = 0,
  }) {
    final name = json['name'] as String? ?? '';
    final path = json['path'] as String? ?? '';
    final isFiles = name == '[Files]';
    return FolderTreeNode(
      path: path,
      name: isFiles
          ? '[Files in this folder]'
          : (name.isNotEmpty ? name : _extractName(path)),
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      fileCount: (json['file_count'] as num?)?.toInt() ?? 0,
      folderCount: (json['folder_count'] as num?)?.toInt() ?? 0,
      driveLetter: drive,
      depth: depth,
      hasChildren: (json['has_children'] as bool?) ?? true,
      isDirectFiles: isFiles,
    );
  }

  static String _extractName(String path) {
    final normalized = path.replaceAll('/', '\\');
    final parts = normalized.split('\\').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return path;
    return parts.last;
  }
}
