// lib/modules/constants.dart
// Global application constants for JA_Symlink

const String appId = 'com.jatech.ja_symlink';
const String appName = 'JA Symlink Manager';
const String appVersion = '1.0.0';

// CSV Configuration
const String csvDelimiter = '|';
const String csvEmptyPlaceholder = 'NONE';
const String csvHeader = 'TIMESTAMP|LINK_PATH|TARGET_PATH|BACKUP_PATH|STATUS';

// Symlink status values
const String statusActive = 'ACTIVE';
const String statusRemoved = 'REMOVED';
const String statusChanged = 'CHANGED';

// Default paths
const String defaultHistoryFile = 'symlink_history.csv';
const String defaultLogFile = 'symlink_history.log';
