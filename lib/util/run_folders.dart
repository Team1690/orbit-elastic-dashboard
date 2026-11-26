import 'dart:io';

/// A run folder that has been closed and stamped with its length.
class FinishedRun {
  const FinishedRun({
    required this.directory,
    required this.baseName,
    required this.seconds,
    required this.isMatch,
  });

  final Directory directory;

  /// The name without the length suffix, e.g. `Run_01` or `log12`.
  final String baseName;
  final int seconds;
  final bool isMatch;
}

/// Creates one folder per run (log + screen recording) under a date folder:
/// `<root>/<d.m.yyyy>/Run_01`, `Run_02`, ...
/// When the run ends the folder gets its length appended (`Run_01_26sec`),
/// and runs from a real match are renamed to the match log name (`log12_26sec`).
class RunFolders {
  RunFolders({required this.rootDirectory});

  final Directory rootDirectory;

  static final RegExp _runPattern = RegExp(r'^Run_(\d+)(_\d+sec)?$');

  /// Match logs from the robot are `log<match number>`; anything else
  /// (a time like `14.05`, or `no log :(`) isn't a match.
  static final RegExp _matchLogPattern = RegExp(r'^log[1-9]\d*$');

  static final RegExp _invalidNameChars = RegExp(r'[\\/:*?"<>|]');

  Directory? _currentRun;
  Directory? get currentRun => _currentRun;

  DateTime? _runStart;
  DateTime? _runEnd;

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
    _runStart = DateTime.now();
    _runEnd = null;
    return runDir;
  }

  /// Marks when the robot stopped running (disable or disconnect).
  /// Only the first mark counts until the run is resumed.
  void markRunEnd() {
    if (_runStart == null) return;
    _runEnd ??= DateTime.now();
  }

  /// The robot was re-enabled before the run was finished.
  void markRunResumed() {
    _runEnd = null;
  }

  /// Appends the run length to the current run folder, and renames it to
  /// [logName] if it's a match log.
  /// Call after the recording has stopped so the video file isn't locked.
  Future<FinishedRun?> finishRun(String? logName) async {
    final Directory? runDir = _currentRun;
    final DateTime? start = _runStart;
    if (runDir == null || start == null) return null;

    final int seconds = (_runEnd ?? DateTime.now()).difference(start).inSeconds;
    _runStart = null;
    _runEnd = null;

    final bool isMatch = logName != null && _matchLogPattern.hasMatch(logName);
    final String baseName = isMatch ? logName : _nameOf(runDir);

    final Directory renamed = await _rename(
      runDir,
      '${baseName}_${seconds}sec',
    );
    // A new run may have started while renaming
    if (identical(_currentRun, runDir)) _currentRun = renamed;

    return FinishedRun(
      directory: renamed,
      baseName: baseName,
      seconds: seconds,
      isMatch: isMatch,
    );
  }

  /// Renames a finished run to `<name>_<seconds>sec`.
  Future<Directory> renameRun(FinishedRun run, String name) {
    final String sanitized = name.trim().replaceAll(_invalidNameChars, '_');
    return _rename(run.directory, '${sanitized}_${run.seconds}sec');
  }

  /// Moves a discarded run into the `JUNK` folder next to it (in the date
  /// folder) instead of deleting it, so it can still be recovered.
  Future<Directory> junkRun(FinishedRun run) async {
    final Directory junkDir = Directory('${run.directory.parent.path}/JUNK');
    await junkDir.create(recursive: true);
    return _rename(run.directory, _nameOf(run.directory), parent: junkDir);
  }

  Future<Directory> _rename(
    Directory dir,
    String newName, {
    Directory? parent,
  }) async {
    parent ??= dir.parent;
    if (parent.path == dir.parent.path && _nameOf(dir) == newName) return dir;

    String targetPath = '${parent.path}/$newName';
    int suffix = 2;
    while (await Directory(targetPath).exists()) {
      targetPath = '${parent.path}/${newName}_${suffix++}';
    }

    // ffmpeg may hold the video open briefly after cancelling
    for (int attempt = 0; attempt < 10; attempt++) {
      try {
        return await dir.rename(targetPath);
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    print('Failed to rename run folder ${dir.path} to $targetPath');
    return dir;
  }

  static String _nameOf(Directory dir) =>
      dir.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
}
