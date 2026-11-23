import 'dart:io';

/// Creates one folder per run (log + screen recording) under a date folder:
/// `<root>/<d.m.yyyy>/Run_01`, `Run_02`, ...
/// Runs from a real match are renamed to the match log name (e.g. `log12`).
class RunFolders {
  RunFolders({required this.rootDirectory});

  final Directory rootDirectory;

  static final RegExp _runPattern = RegExp(r'^Run_(\d+)$');

  /// Match logs from the robot are `log<match number>`; anything else
  /// (a time like `14.05`, or `no log :(`) isn't a match.
  static final RegExp _matchLogPattern = RegExp(r'^log[1-9]\d*$');

  Directory? _currentRun;
  Directory? get currentRun => _currentRun;

  // Remembered in memory too, since renamed runs no longer show up as Run_NN
  String? _lastRunDate;
  int _lastRunNumber = 0;

  String get _todayName {
    final DateTime now = DateTime.now();
    return '${now.day}.${now.month}.${now.year}';
  }

  Directory get todayDirectory =>
      Directory('${rootDirectory.path}/$_todayName');

  /// Creates the next sequentially numbered run folder for today.
  /// Sync so concurrent enable events can't grab the same number.
  Directory startRun() {
    final String today = _todayName;
    final Directory dateDir = todayDirectory;
    dateDir.createSync(recursive: true);

    int maxRun = _lastRunDate == today ? _lastRunNumber : 0;
    for (final FileSystemEntity entity in dateDir.listSync()) {
      if (entity is! Directory) continue;
      final RegExpMatch? match = _runPattern.firstMatch(_nameOf(entity));
      if (match != null) {
        final int number = int.parse(match.group(1)!);
        if (number > maxRun) maxRun = number;
      }
    }

    _lastRunDate = today;
    _lastRunNumber = maxRun + 1;

    final Directory runDir = Directory(
      '${dateDir.path}/Run_${_lastRunNumber.toString().padLeft(2, '0')}',
    );
    runDir.createSync(recursive: true);
    _currentRun = runDir;
    return runDir;
  }

  /// Renames the current run folder to [logName] if it's a match log.
  /// Call after the recording has stopped so the video file isn't locked.
  Future<void> finishRun(String? logName) async {
    final Directory? runDir = _currentRun;
    if (runDir == null ||
        logName == null ||
        !_matchLogPattern.hasMatch(logName) ||
        _nameOf(runDir) == logName) {
      return;
    }

    final Directory parent = runDir.parent;
    String targetPath = '${parent.path}/$logName';
    int suffix = 2;
    while (await Directory(targetPath).exists()) {
      targetPath = '${parent.path}/${logName}_${suffix++}';
    }

    // ffmpeg may hold the video open briefly after cancelling
    for (int attempt = 0; attempt < 10; attempt++) {
      try {
        _currentRun = await runDir.rename(targetPath);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    print('Failed to rename run folder ${runDir.path} to $targetPath');
  }

  static String _nameOf(Directory dir) =>
      dir.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
}
