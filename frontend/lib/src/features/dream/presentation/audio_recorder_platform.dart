import 'package:record/record.dart';

abstract class AudioRecorderPlatform {
  Future<void> start(AudioRecorder recorder, RecordConfig config);
  Future<String?> stop(AudioRecorder recorder);
  Future<List<int>> getAudioBytes(String path);
}
