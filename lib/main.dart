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
      title: 'Deep Translator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue.shade200),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: ''),
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
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 35.0),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            ),
          ),
        ],
      ),
      endDrawer: const Drawer(
          // Add your drawer widgets here
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
                          if (data == RecordState.record) ...[
                            Text(
                              'Translating...',
                              style: TextStyle(
                                color: Colors.lightBlue.shade400,
                                fontSize: 20,
                                fontFamily: 'Thin',
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            ElevatedButton(
                              onPressed: translator
                                  .stopRecording, // Implement language change feature
                              style: ElevatedButton.styleFrom(
                                surfaceTintColor: const Color(0XFFFFFFFF),
                                shadowColor: Colors.lightBlue.shade200,
                                elevation: 4.0,
                                shape: RoundedRectangleBorder(
                                    side: BorderSide(
                                        color: Colors.lightBlue.shade100,
                                        width: 1.5),
                                    borderRadius: BorderRadius.circular(50)),
                                fixedSize: const Size(300, 300),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: StreamBuilder(
                                  stream: translator.translationHistoryStream,
                                  builder: (context, snapshot) {
                                    switch (snapshot.connectionState) {
                                      case ConnectionState.done:
                                      case ConnectionState.active:
                                        final data = snapshot.data!;
                                        return SingleChildScrollView(
                                          reverse: true,
                                          child: Text(
                                            data,
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                        );
                                      default:
                                        return const Text('');
                                    }
                                  },
                                ),
                              ),
                            ),
                          ] else
                            ElevatedButton(
                              onPressed: translator
                                  .startRecording, // Implement language change feature
                              style: ElevatedButton.styleFrom(
                                surfaceTintColor: const Color(0XFFFFFFFF),
                                shadowColor: Colors.lightBlue.shade200,
                                elevation: 4.0,
                                shape: CircleBorder(
                                    side: BorderSide(
                                        color: Colors.lightBlue.shade100,
                                        width: 1.5)),
                                fixedSize: const Size(300, 300),
                              ),
                              child: Text(
                                'Translate',
                                style: TextStyle(
                                  color: Colors.lightBlue.shade400,
                                  fontSize: 50,
                                  fontFamily: 'Thin',
                                  fontWeight: FontWeight.w200,
                                ),
                              ),
                            ),
                          const SizedBox(height: 25),
                          ElevatedButton(
                            onPressed:
                                () {}, // Implement language change feature
                            style: ElevatedButton.styleFrom(
                              surfaceTintColor: const Color(0XFFFFFFFF),
                              shadowColor: Colors.lightBlue.shade200,
                              elevation: 4.0,
                              shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                      color: Colors.lightBlue.shade100,
                                      width: 1.5),
                                  borderRadius: BorderRadius.circular(25)),
                              fixedSize: const Size(300, 80),
                            ),
                            child: Text(
                              'English',
                              style: TextStyle(
                                color: Colors.lightBlue.shade400,
                                fontSize: 30,
                                fontFamily: 'Thin',
                                fontWeight: FontWeight.w200,
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),
                          ElevatedButton(
                            onPressed:
                                () {}, // Implement language change feature
                            style: ElevatedButton.styleFrom(
                              surfaceTintColor: const Color(0XFFFFFFFF),
                              shadowColor: Colors.lightBlue.shade200,
                              elevation: 4.0,
                              shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                      color: Colors.lightBlue.shade100,
                                      width: 1.5),
                                  borderRadius: BorderRadius.circular(25)),
                              fixedSize: const Size(300, 80),
                            ),
                            child: Text(
                              'Settings',
                              style: TextStyle(
                                color: Colors.lightBlue.shade400,
                                fontSize: 30,
                                fontFamily: 'Thin',
                                fontWeight: FontWeight.w200,
                              ),
                            ),
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
