// lib/modules/relocator/relocator_model.dart
// Data models for 1-Click Smart Relocator feature.

import 'package:flutter/material.dart';

enum RelocatorCategory {
  all('all', 'Tất cả', Icons.apps_rounded),
  ai('ai', 'AI & Machine Learning', Icons.psychology_rounded),
  dev('dev', 'Lập trình & SDK', Icons.terminal_rounded),
  media('media', 'Đồ họa & Media', Icons.movie_filter_rounded),
  game('game', 'Game & Mods', Icons.sports_esports_rounded);

  final String id;
  final String label;
  final IconData icon;
  const RelocatorCategory(this.id, this.label, this.icon);
}

enum RelocatorStatus {
  idle,
  scanning,
  detected,
  alreadySymlinked,
  notFound,
  relocating,
  completed,
  error,
}

class RelocatorPreset {
  final String id;
  final String name;
  final String description;
  final RelocatorCategory category;
  final IconData icon;
  final Color? accentColor;
  final String Function() pathResolver;

  String? actualPath;
  int sizeBytes;
  int fileCount;
  RelocatorStatus status;
  String? statusMessage;
  String? existingTargetPath;

  RelocatorPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    this.accentColor,
    required this.pathResolver,
    this.actualPath,
    this.sizeBytes = 0,
    this.fileCount = 0,
    this.status = RelocatorStatus.idle,
    this.statusMessage,
    this.existingTargetPath,
  });

  String get formattedSize {
    if (sizeBytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int unitIndex = 0;
    double size = sizeBytes.toDouble();
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(size >= 10 || unitIndex == 0 ? 1 : 2)} ${units[unitIndex]}';
  }

  bool get isRelocatable => status == RelocatorStatus.detected && sizeBytes > 0;
}

class DriveTargetInfo {
  final String letter; // e.g. 'D:'
  final int freeBytes;
  final int totalBytes;

  const DriveTargetInfo({
    required this.letter,
    required this.freeBytes,
    required this.totalBytes,
  });

  String get formattedFree {
    final gb = freeBytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB trống';
  }

  String get formattedTotal {
    final gb = totalBytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(0)} GB';
  }

  double get percentFree {
    if (totalBytes <= 0) return 0.0;
    return (freeBytes / totalBytes).clamp(0.0, 1.0);
  }
}
