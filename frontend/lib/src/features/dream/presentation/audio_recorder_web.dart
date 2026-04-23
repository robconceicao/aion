import 'package:record/record.dart';
import 'package:dio/dio.dart';
import 'audio_recorder_platform.dart';

class AudioRecorderWeb implements AudioRecorderPlatform {
  @override
  Future<void> start(AudioRecorder recorder, RecordConfig config) async {
    // Na Web, o path vazio faz o Record usar BLOBs internos
    await recorder.start(config, path: '');
  }

  @override
  Future<String?> stop(AudioRecorder recorder) async {
    return await recorder.stop();
  }

  @override
  Future<List<int>> getAudioBytes(String path) async {
    final dio = Dio();
    final response = await dio.get(path, options: Options(responseType: ResponseType.bytes));
    return response.data as List<int>;
  }
}

AudioRecorderPlatform getRecorder() => AudioRecorderWeb();
