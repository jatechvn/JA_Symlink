// lib/modules/shell/shell_context_menu.dart
// Manages Windows Explorer Right-Click Context Menu integration for directories and backgrounds.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

final _logger = Logger('ShellContextMenu');

class ShellContextMenuService {
  @visibleForTesting
  static Future<ProcessResult> Function(List<String>) runRegistry = (args) =>
      Process.run('reg', args);
  static const String _folderKey = r'HKCR\Directory\shell\JASymlink';
  static const String _backgroundKey =
      r'HKCR\Directory\Background\shell\JASymlink';

  /// Check if Windows Explorer context menu entries are registered
  static Future<bool> isRegistered() async {
    if (!Platform.isWindows) return false;

    try {
      for (final key in [_folderKey, _backgroundKey]) {
        final result = await runRegistry(['query', '$key\\command', '/ve']);
        if (result.exitCode != 0) return false;
      }
      return true;
    } catch (e) {
      _logger.warning('Failed to query shell context menu registry: $e');
      return false;
    }
  }

  /// Register context menu entries in Windows Explorer
  static Future<bool> register({
    String? customExePath,
    String? label,
    String? bgLabel,
  }) async {
    if (!Platform.isWindows) return false;

    final exePath = customExePath ?? Platform.resolvedExecutable;
    final sourceLabel = label ?? 'Tạo Symbolic Link (JA Symlink)';
    final targetLabel = bgLabel ?? 'Đặt làm Đích Symlink tại đây (JA Symlink)';

    try {
      // 1. Register for Folders/Directories (Right-click folder -> Source)
      await _runReg(['add', _folderKey, '/ve', '/d', sourceLabel, '/f']);
      await _runReg([
        'add',
        _folderKey,
        '/v',
        'Icon',
        '/d',
        '"$exePath"',
        '/f',
      ]);
      await _runReg([
        'add',
        '$_folderKey\\command',
        '/ve',
        '/d',
        '"$exePath" --source "%1"',
        '/f',
      ]);

      // 2. Register for Directory Backgrounds (Right-click inside folder -> Target)
      await _runReg(['add', _backgroundKey, '/ve', '/d', targetLabel, '/f']);
      await _runReg([
        'add',
        _backgroundKey,
        '/v',
        'Icon',
        '/d',
        '"$exePath"',
        '/f',
      ]);
      await _runReg([
        'add',
        '$_backgroundKey\\command',
        '/ve',
        '/d',
        '"$exePath" --target "%V"',
        '/f',
      ]);

      _logger.info('Registered Windows Explorer context menu successfully');
      return isRegistered();
    } catch (e) {
      _logger.severe('Failed to register context menu: $e');
      return false;
    }
  }

  /// Remove context menu entries from Windows Explorer
  static Future<bool> unregister() async {
    if (!Platform.isWindows) return false;

    try {
      bool succeeded = true;
      for (final key in [_folderKey, _backgroundKey]) {
        final result = await runRegistry(['delete', key, '/f']);
        if (result.exitCode != 0) succeeded = false;
        final remaining = await runRegistry(['query', key]);
        if (remaining.exitCode == 0) succeeded = false;
      }
      _logger.info('Unregistered Windows Explorer context menu');
      return succeeded;
    } catch (e) {
      _logger.warning('Failed to unregister context menu: $e');
      return false;
    }
  }

  static Future<ProcessResult> _runReg(List<String> args) async {
    final result = await runRegistry(args);
    if (result.exitCode != 0) {
      throw ProcessException('reg', args, '${result.stderr}', result.exitCode);
    }
    return result;
  }
}
