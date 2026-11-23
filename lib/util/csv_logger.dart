import 'dart:io';

class CsvLogger {
  CsvLogger({
    required this.logDirectory,
  });

  final Directory logDirectory;

  File? _file;
  String? _logName;
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
    _header = null;
    _lines.clear();

    if (!await logDirectory.exists()) {
      await logDirectory.create(recursive: true);
    }

    _file = File('${logDirectory.path}/$_logName.csv');
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
  void finishLog() {
    if (_file == null || _lines.length <= 1) {
      return;
    }

    // Capture local variables in case state changes during async I/O
    final File fileToSave = _file!;
    final String? headerToSave = _header;
    final List<String> linesToSave = List.from(_lines);

    // Reset logger state immediately so new logs can start cleanly

    _lines.clear();

    try {
      if (!logDirectory.existsSync()) {
        logDirectory.createSync(recursive: true);
      }

      // Open file for writing (Mode: WRITE completely overwrites old content cleanly)
      final RandomAccessFile sink = fileToSave.openSync(
        mode: FileMode.writeOnlyAppend,
      );
      // 1. Header (Metadata)
      if (headerToSave != null && headerToSave.isNotEmpty) {
        sink.write(headerToSave); // header already ends with "\n"
      }

      print(linesToSave.length);

      sink.writeStringSync(_titles); // "," happens in robot code
      // 2. Data rows
      for (final String line in linesToSave) {
        sink.writeString(line);
      }

      sink.flushSync();
      sink.closeSync();

      print("Successfully saved: ${fileToSave.path}");
    } catch (e) {
      print("Failed to save CSV log to ${fileToSave.path}: $e");
    }
  }

  /// In case the app closes unexpectedly.
  void dispose() {
    if (_isLogging) {
      finishLog();
    }
  }
}
