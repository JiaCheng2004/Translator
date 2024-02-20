import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:translator/translator.dart';

void main() async {
  await dotenv.load(fileName: '.env');
  String? apiKey = dotenv.env['OPEN_AI_API_KEY'];

  if (apiKey == null) {
    throw Exception('Please provide an OpenAI API key in your .env file.');
  }

  OpenAI.apiKey = apiKey;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final translator = Translator();

  @override
  void dispose() {
    translator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: FutureBuilder(
        future: Permission.microphone.status,
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.done:
              final permStatus = snapshot.data!;
              print(permStatus);
              if (permStatus != PermissionStatus.granted) {
                Permission.microphone.request().then((val) => print(val));
                print('Please accept permissions');
              }

              return StreamBuilder(
                initialData: RecordState.stop,
                stream: translator.recorder.onStateChanged(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final RecordState data = snapshot.data!;
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Text(data.name),
                          data == RecordState.record
                              ? TextButton(
                                  onPressed: translator.pauseRecording,
                                  child: const Text('Recording...'),
                                )
                              : TextButton(
                                  onPressed: translator.startRecording,
                                  child: const Text('Start Translating'),
                                )
                        ],
                      ),
                    );
                  }
                  return const Text('Not recording');
                },
              );

            default:
              return const CircularProgressIndicator();
          }
        },
      ),
    );
  }
}
