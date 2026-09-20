// lib/modules/storage/storage_model.dart
// Data models for Live Drive Space and Storage Savings calculations

import '../utils.dart';

/// Type of logical drive on Windows
enum DriveKind { localFixed, removable, network, unknown }

/// Urgency level based on drive fullness
enum DriveUrgency {
  normal, // < 80% used
  warning, // 80% - 92% used
  critical, // >= 92% used
}

/// Represents a logical Windows drive with storage telemetry
class DriveSpaceInfo {
  final String letter; // e.g. 'C:', 'D:'
  final String label; // e.g. 'Windows', 'Data', 'NVMe_Game'
  final DriveKind driveKind;
  final int totalBytes;
  final int freeBytes;

  const DriveSpaceInfo({
    required this.letter,
    required this.label,
    required this.driveKind,
    required this.totalBytes,
    required this.freeBytes,
  });

  int get usedBytes => (totalBytes - freeBytes).clamp(0, totalBytes);

  double get usedPercent {
    if (totalBytes <= 0) return 0.0;
    return (usedBytes / totalBytes).clamp(0.0, 1.0);
  }

  double get freePercent {
    if (totalBytes <= 0) return 0.0;
    return (freeBytes / totalBytes).clamp(0.0, 1.0);
  }

  bool get isSystemDrive => letter.toUpperCase().startsWith('C:');

  DriveUrgency get urgency {
    if (usedPercent >= 0.92) return DriveUrgency.critical;
    if (usedPercent >= 0.80) return DriveUrgency.warning;
    return DriveUrgency.normal;
  }

  String get formattedFree => formatFileSize(freeBytes);
  String get formattedTotal => formatFileSize(totalBytes);
  String get formattedUsed => formatFileSize(usedBytes);

  String get displayTitle {
    if (label.isEmpty) return letter;
    return '$letter ($label)';
  }

  DriveSpaceInfo copyWith({
    String? letter,
    String? label,
    DriveKind? driveKind,
    int? totalBytes,
    int? freeBytes,
  }) {
    return DriveSpaceInfo(
      letter: letter ?? this.letter,
      label: label ?? this.label,
      driveKind: driveKind ?? this.driveKind,
      totalBytes: totalBytes ?? this.totalBytes,
      freeBytes: freeBytes ?? this.freeBytes,
    );
  }

  @override
  String toString() =>
      'DriveSpaceInfo($letter, label: $label, used: ${(usedPercent * 100).toStringAsFixed(1)}%)';
}

/// Storage statistics of an individual symlink's target directory
class SymlinkStorageStat {
  final String linkPath;
  final String targetPath;
  final int sizeBytes;
  final int fileCount;
  final bool isOffloadedFromC;
  final DateTime lastScanned;

  const SymlinkStorageStat({
    required this.linkPath,
    required this.targetPath,
    required this.sizeBytes,
    required this.fileCount,
    required this.isOffloadedFromC,
    required this.lastScanned,
  });

  String get formattedSize => formatFileSize(sizeBytes);

  @override
  String toString() =>
      'SymlinkStorageStat(target: $targetPath, size: $formattedSize, files: $fileCount)';
}

/// Overall storage savings summary across the system
class StorageSavingsSummary {
  final int totalSavedBytes;
  final int totalSavedOnCBytes;
  final int activeLinkCount;
  final int totalFileCount;
  final Map<String, int> perDriveSavings;

  const StorageSavingsSummary({
    required this.totalSavedBytes,
    required this.totalSavedOnCBytes,
    required this.activeLinkCount,
    required this.totalFileCount,
    required this.perDriveSavings,
  });

  static const StorageSavingsSummary empty = StorageSavingsSummary(
    totalSavedBytes: 0,
    totalSavedOnCBytes: 0,
    activeLinkCount: 0,
    totalFileCount: 0,
    perDriveSavings: {},
  );

  String get formattedTotalSaved => formatFileSize(totalSavedBytes);
  String get formattedSavedOnC => formatFileSize(totalSavedOnCBytes);

  double get savedOnCGigabytes => totalSavedOnCBytes / (1024 * 1024 * 1024);

  double get totalSavedGigabytes => totalSavedBytes / (1024 * 1024 * 1024);

  @override
  String toString() =>
      'StorageSavingsSummary(savedOnC: $formattedSavedOnC, links: $activeLinkCount)';
}
