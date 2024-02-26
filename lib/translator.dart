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

typedef TranslationCompleteHandler = void Function(String);

class Translator {
  // Normalization constants
  static const pcm16BitMax = 32767;
  static const pcm16BitMin = pcm16BitMax + 1;
  static const reductionRatio = 0.7;

  static const sparsityThreshold = 0.8;
  static const audioCaptureSeconds = 5;
  static const recorderSettings = RecordConfig(encoder: AudioEncoder.pcm16bits);
  static const recordingFileName = 'translator_data.wav';
  static const translationFileName = 'translation';

  final recorder = AudioRecorder();
  StreamController<String> translationHistory =
      StreamController<String>.broadcast();
  StreamSubscription<Uint8List>? subscription;

  List<double> leftBuffer = [];
  List<double> rightBuffer = [];
  String sessionText = '';

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
        double val = _reduceSound(_rescale(signedPCMData[i]));

        if (i % 2 == 0) {
          leftBuffer.add(val);
        } else {
          rightBuffer.add(val);
        }
      }

      final bufferMaxLen = recorderSettings.sampleRate * audioCaptureSeconds;
      if (leftBuffer.length >= bufferMaxLen) {
        pauseRecording();
      }
    });
  }

  void stopRecording() async {
    await recorder.stop();
    await subscription?.cancel();

    sessionText = '';
    leftBuffer = [];
    rightBuffer = [];
    subscription = null;
  }

  void pauseRecording() async {
    if (_isSparse()) {
      leftBuffer = [];
      rightBuffer = [];
      return;
    }

    final directory = await getApplicationCacheDirectory();
    final file = File('${directory.path}/$recordingFileName');
    final wav = Wav(
      [
        Float64List.fromList(leftBuffer),
        Float64List.fromList(rightBuffer),
      ],
      recorderSettings.sampleRate,
    );
    leftBuffer = [];
    rightBuffer = [];
    await wav.writeFile(file.path);

    final translatedString = await translateAudioFile(file);

    if (translatedString.trim().isNotEmpty) {
      sessionText += ' $translatedString';
      translationHistory.add(sessionText);
      await playText(translatedString);
    }
  }

  Stream<String> get translationHistoryStream => translationHistory.stream;

  Future<String> translateAudioFile(File file) async {
    if (file.path.split('.').last != 'wav') {
      throw IllegalArgumentException('Invalid file argument: ${file.path}');
    }
    final translation = await OpenAI.instance.audio.createTranslation(
      file: file,
      model: 'whisper-1',
      prompt: 'English only, session: $sessionText',
      // 'ALL OUTPUTS SHOULD BE IN ENGLISH!!!! Please DO NOT add your own voice!'
      // 'Also connect the message to the whole conversation to make it flow nicely'
      // 'like a translation stream. This is the previous text: $sessionText',
      responseFormat: OpenAIAudioResponseFormat.text,
    );
    return translation.text;
  }

  Future<void> playAudioFile(File file) async {
    final player = AudioPlayer();
    await player.setFilePath(file.path);
    await player.play();
  }

  Future<void> playText(String text) async {
    final directory = await getApplicationCacheDirectory();
    File speechFile = await OpenAI.instance.audio.createSpeech(
      model: 'tts-1',
      voice: 'nova',
      input: text,
      responseFormat: OpenAIAudioSpeechResponseFormat.aac,
      outputDirectory: directory,
      outputFileName: translationFileName,
    );
    playAudioFile(speechFile);
  }

  bool _isSparse() {
    final sparseCount = leftBuffer.where((sample) => sample.abs() < 0.1).length;
    return (sparseCount / leftBuffer.length) > sparsityThreshold;
  }

  double _rescale(int val) {
    if (val > 0) {
      return val / pcm16BitMax;
    }
    return val / pcm16BitMin;
  }

  double _reduceSound(double val) {
    return reductionRatio * val;
  }
}
