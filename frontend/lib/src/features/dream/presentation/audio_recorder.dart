import 'audio_recorder_native.dart'
    if (dart.library.html) 'audio_recorder_web.dart';
import 'audio_recorder_platform.dart';

AudioRecorderPlatform getPlatformRecorder() {
  return getRecorder();
}
