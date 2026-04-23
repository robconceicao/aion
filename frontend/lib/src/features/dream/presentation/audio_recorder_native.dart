import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'audio_recorder_platform.dart';

class AudioRecorderNative implements AudioRecorderPlatform {
  @override
  Future<void> start(AudioRecorder recorder, RecordConfig config) async {
    if (await Permission.microphone.request().isGranted) {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/dream_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await recorder.start(config, path: path);
    }
  }

  @override
  Future<String?> stop(AudioRecorder recorder) async {
    return await recorder.stop();
  }

  @override
  Future<List<int>> getAudioBytes(String path) async {
    return await File(path).readAsBytes();
  }
}

AudioRecorderPlatform getRecorder() => AudioRecorderNative();
