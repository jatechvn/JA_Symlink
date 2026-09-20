// lib/modules/process/process_lock_model.dart
// Data model representing a process locking files or directories.

class ProcessLockInfo {
  final int pid;
  final String name;
  final String description;
  final String windowTitle;
  final String executablePath;

  const ProcessLockInfo({
    required this.pid,
    required this.name,
    this.description = '',
    this.windowTitle = '',
    this.executablePath = '',
  });

  factory ProcessLockInfo.fromJson(Map<String, dynamic> json) {
    return ProcessLockInfo(
      pid: json['Id'] as int? ?? (json['pid'] as int? ?? 0),
      name:
          (json['ProcessName'] as String?) ??
          (json['name'] as String?) ??
          'Unknown',
      description:
          (json['Description'] as String?) ??
          (json['description'] as String?) ??
          '',
      windowTitle:
          (json['MainWindowTitle'] as String?) ??
          (json['windowTitle'] as String?) ??
          '',
      executablePath:
          (json['Path'] as String?) ??
          (json['executablePath'] as String?) ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pid': pid,
      'name': name,
      'description': description,
      'windowTitle': windowTitle,
      'executablePath': executablePath,
    };
  }

  /// User-friendly name: prefers description if available, falls back to process name
  String get displayName {
    if (description.trim().isNotEmpty) {
      return description.trim();
    }
    return name;
  }

  @override
  String toString() => '$displayName (PID: $pid)';
}
