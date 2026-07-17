import 'dart:io';

import 'wonelog_api.dart';

class BackendManager {
  BackendManager({required this.api});

  final WonelogApi api;

  Future<bool> isRunning() async {
    try {
      final health = await api.health();
      return health['status'] == 'running';
    } catch (_) {
      return false;
    }
  }

  Future<bool> ensureRunning() async {
    if (await isRunning()) return true;

    final exe = findBackendExecutable();
    if (exe == null) return false;

    try {
      await Process.start(
        exe.path,
        const <String>[],
        mode: ProcessStartMode.detached,
        runInShell: true,
        workingDirectory: exe.parent.path,
      );
    } catch (_) {
      return false;
    }

    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (await isRunning()) return true;
    }
    return false;
  }

  File? findBackendExecutable() {
    const exeName = 'Wonelog\u7ba1\u7406\u540e\u53f0.exe';
    final roots = <Directory>{
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    };

    for (final root in List<Directory>.from(roots)) {
      Directory? cursor = root;
      for (var i = 0; i < 8 && cursor != null; i++) {
        roots.add(cursor);
        cursor = cursor.parent.path == cursor.path ? null : cursor.parent;
      }
    }

    final relativeCandidates = <String>[
      exeName,
      'release${Platform.pathSeparator}$exeName',
      'core${Platform.pathSeparator}$exeName',
      '..${Platform.pathSeparator}release${Platform.pathSeparator}$exeName',
      '..${Platform.pathSeparator}core${Platform.pathSeparator}$exeName',
    ];

    for (final root in roots) {
      for (final relative in relativeCandidates) {
        final file = File('${root.path}${Platform.pathSeparator}$relative');
        if (file.existsSync()) return file;
      }
    }
    return null;
  }
}
