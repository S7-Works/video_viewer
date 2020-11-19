import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_viewer/video_viewer.dart';

void main() => runApp(App());

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return MaterialApp(
      home: HomePage(),
      title: 'Video Viewer Example',
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, String> src = {
    "1080p":
        "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
    "720p":
        "https://file-examples-com.github.io/uploads/2017/04/file_example_MP4_480_1_5MG.mp4",
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: VideoViewer(source: getNetworkVideoSources(src)),
    );
  }

  // Widget videoWithCacheSources() {
  //   return FutureBuilder<Map<String, dynamic>>(
  //     future: getCachedVideoSources(src),
  //     builder: (_, AsyncSnapshot<Map<String, dynamic>> snapshot) {
  //       if (snapshot.hasData)
  //         return VideoViewer(source: snapshot.data);
  //       else
  //         return CircularProgressIndicator();
  //     },
  //   );
  // }
}