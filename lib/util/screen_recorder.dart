import 'dart:io';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

class ScreenRecorder {
  static bool isRecording = false;
  static Future<void> start(Directory outputDirectory) async {
    isRecording = true;
    final String outputPath = '${outputDirectory.path}/${_getFileName()}'
        .replaceAll('/', '\\');
    final String ffmpegCommand =
        '-y -f gdigrab -framerate 30 -i desktop -c:v mpeg4 -q:v 3 -pix_fmt yuv420p -movflags frag_keyframe+empty_moov "$outputPath"';

    await FFmpegKit.executeAsync(ffmpegCommand);
  }

  /// Completes once the ffmpeg sessions have been told to cancel.
  static Future<void> stop() async {
    isRecording = false;
    await Future<void>.delayed(const Duration(seconds: 1));
    FFmpegKitExtended.cancelAllSessions();
  }

  static String _getFileName() {
    final DateTime now = DateTime.now();
    return 'screen_record_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}.mp4';
  }
}
