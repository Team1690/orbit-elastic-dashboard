import 'dart:io';

import 'package:elastic_dashboard/util/run_folders.dart';

class CsvLogger {
  CsvLogger({
    required this.runFolders,
  });

  final RunFolders runFolders;

  /// The current run's folder, or today's date folder if no run has started.
  Directory get logDirectory =>
      runFolders.currentRun ?? runFolders.todayDirectory;

  String? _logName;
  String? get logName => _logName;
  String? _header;

  final List<String> _lines = [];
  String _titles = '';

  bool _isLogging = false;
  bool get isLogging => _isLogging;
  bool get linesIsEmpty => _lines.isEmpty;

  /// Called when a new log begins.
  /// Called when a new log begins.
  Future<void> startLog(String logName) async {
    // Sanitize filename to prevent OS invalid character errors (\, /, :, *, ?, ", <, >, |)
    final String sanitizedName = logName.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );

    // If we're already logging under this exact name, this is just a
    // re-publish of the same value (robot loop re-sends every cycle) —
    // do nothing so we don't wipe out accumulated lines.
    if (_isLogging && _logName == sanitizedName) {
      return;
    }

    // final bool wasLogging = _isLogging;
    _isLogging = logName.isNotEmpty;

    // if (wasLogging) {
    //   await finishLog();
    // }

    if (!_isLogging) {
      return;
    }

    _logName = sanitizedName;
    // Keep the previous header: if the robot's header didn't change, NT may
    // not send it again, and the last one is still correct.
    _lines.clear();
  }

  /// Called to set top-level metadata or header text.
  void setHeader(String header) {
    _header = header;
  }

  /// Appends a line (either column Titles or Data rows).
  void addLine(String csvLine) {
    if (!_isLogging) return;
    if (_lines.isNotEmpty && _lines.last == csvLine)
      return; // skip exact repeat
    _lines.add(csvLine);
  }

  void addTitles(String titles) {
    if (!_isLogging) return;
    _titles = titles;
  }

  /// Writes the finished CSV to disk.
  Future<void> finishLog() async {
    if (_logName == null || _lines.length <= 1) {
      return;
    }

    // Capture local variables in case state changes during async I/O
    final Directory dirToSave = logDirectory;
    final File fileToSave = File('${dirToSave.path}/$_logName.csv');
    final String? headerToSave = _header;
    final List<String> linesToSave = List.from(_lines);

    // Reset logger state immediately so new logs can start cleanly

    _lines.clear();

    try {
      if (!await dirToSave.exists()) {
        await dirToSave.create(recursive: true);
      }

      // Open file for writing (Mode: WRITE completely overwrites old content cleanly)
      final IOSink sink = fileToSave.openWrite(mode: FileMode.write);

      // 1. Header (Metadata)
      if (headerToSave != null && headerToSave.isNotEmpty) {
        sink.write(headerToSave); // header already ends with "\n"
      }

      print(linesToSave.length);

      sink.writeln(_titles); // "," happens in robot code
      // 2. Data rows
      for (final line in linesToSave) {
        sink.writeln(line);
      }

      await sink.flush();
      await sink.close();

      print("Successfully saved: ${fileToSave.path}");
    } catch (e) {
      print("Failed to save CSV log to ${fileToSave.path}: $e");
    }
  }

  /// In case the app closes unexpectedly.
  Future<void> dispose() async {
    if (_isLogging) {
      await finishLog();
    }
  }
}
