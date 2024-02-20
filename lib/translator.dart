import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_openai/dart_openai.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:wav/wav_file.dart';
import 'package:wav/wav.dart';

class IllegalArgumentException implements Exception {
  final String msg;
  IllegalArgumentException(this.msg);
}

class Translator {
  static const recorderSettings = RecordConfig(encoder: AudioEncoder.pcm16bits);
  final recorder = AudioRecorder();
  StreamSubscription<Uint8List>? subscription;
  List<double> leftBuffer = [];
  List<double> rightBuffer = [];

  static final Translator _instance = Translator._sharedInstance();

  factory Translator() {
    return _instance;
  }

  Translator._sharedInstance();

  void dispose() async {
    await subscription?.cancel();
  }

  void startRecording() async {
    if (subscription != null) {
      await recorder.resume();
      return;
    }

    final recordStream = await recorder.startStream(recorderSettings);
    subscription = recordStream.listen((bytes) {
      final signedPCMData = recorder.convertBytesToInt16(bytes);
      for (int i = 0; i < signedPCMData.length; i++) {
        if (i % 2 == 0) {
          leftBuffer.add(signedPCMData[i].toDouble());
        } else {
          rightBuffer.add(signedPCMData[i].toDouble());
        }
      }
    });
  }

  void pauseRecording() async {
    await recorder.pause();
    final directory = await getApplicationCacheDirectory();
    final file = File('${directory.path}/translator_data.wav');

    final wav = Wav(
      [
        Float64List.fromList(leftBuffer),
        Float64List.fromList(rightBuffer),
      ],
      recorderSettings.sampleRate,
    );
    await wav.writeFile(file.path);

    leftBuffer = [];
    rightBuffer = [];
    await playAudioFile(file);
    await file.delete();
  }

  Future<String> translateAudioFile(File file) async {
    if (file.path.split('.').last != 'wav') {
      throw IllegalArgumentException('Invalid file argument: ${file.path}');
    }
    final translation = await OpenAI.instance.audio.createTranslation(
      file: file,
      model: 'whisper-1',
      prompt:
          'Translate the audio to english, making it sound as local to english as possible.',
      responseFormat: OpenAIAudioResponseFormat.text,
    );
    return translation.text;
  }

  Future<void> playAudioFile(File file) async {
    if (file.path.split('.').last != 'wav') {
      throw IllegalArgumentException('Invalid file argument: ${file.path}');
    }
    final player = AudioPlayer();
    await player.setFilePath(file.path);
    await player.play();
  }
}
