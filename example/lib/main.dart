import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:example/chapter_drawer.dart';
import 'package:example/search_page.dart';
import 'package:flutter/material.dart';

void main() {
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
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Epub Viewer Demo'),
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
  final epubController = EpubController();

  var textSelectionCfi = '';

  bool isLoading = true;

  double progress = 0.0;
  
  EpubFlow _epubFlow = EpubFlow.paginated;

  String getFontUri(ByteData data, String mime) {
    final buffer = data.buffer;
    return Uri.dataFromBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        mimeType: mime)
        .toString();
  }

  Future<String> fontToBase64(String assetPath) async {
    ByteData bytes = await rootBundle.load(assetPath);
    List<int> fontBytes = bytes.buffer.asUint8List();
    String base64Str = base64Encode(fontBytes);
    return "data:font/ttf;base64,$base64Str";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: ChapterDrawer(
        controller: epubController,
      ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title,style: TextStyle(
            fontSize: 24,
            fontFamily: 'CordiaUPC',
            fontWeight: FontWeight.bold
        )),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SearchPage(
                            epubController: epubController,
                          )));
            },
          ),
          IconButton(
            icon: Text(_epubFlow == EpubFlow.paginated ? 'h' : 'v'),
            onPressed: () async {
              if(_epubFlow == EpubFlow.paginated){
                setState(() {
                  _epubFlow = EpubFlow.scrolled;
                  epubController.setFlow(flow: EpubFlow.scrolled);
                  epubController.webViewController?.reload();
                });
              }else{
                setState(() {
                  _epubFlow = EpubFlow.paginated;
                  epubController.setFlow(flow: EpubFlow.paginated);
                });
              }
              // String base64Font = await fontToBase64("assets/fonts/Bariol_Regular.otf");
              // epubController.injectFontIntoWebView(base64Font, "Bariol");
            },
          ),
        ],
      ),
      body: SafeArea(
          child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.transparent,
          ),
          Expanded(
            child: Stack(
              children: [
                EpubViewer(
                  epubSource: EpubSource.fromUrl(
                      'https://vocsyinfotech.in/envato/cc/flutter_ebook/uploads/22566_The-Racketeer---John-Grisham.epub'),
                  // 'https://github.com/IDPF/epub3-samples/releases/download/20230704/accessible_epub_3.epub'),
                  epubController: epubController,
                  displaySettings: EpubDisplaySettings(
                      flow: _epubFlow,
                      useSnapAnimationAndroid: false,
                      snap: true,
                      theme: EpubTheme.light(),
                      allowScriptedContent: true),
                  selectionContextMenu: ContextMenu(
                    menuItems: [
                      ContextMenuItem(
                        title: "Highlight",
                        id: 1,
                        action: () async {
                          epubController.addHighlight(cfi: textSelectionCfi);
                        },
                      ),
                    ],
                    settings: ContextMenuSettings(
                        hideDefaultSystemContextMenuItems: true),
                  ),
                  onChaptersLoaded: (chapters) {
                    print(chapters);
                    setState(() {
                      isLoading = false;
                    });
                  },
                  onEpubLoaded: () async {
                    print('Epub loaded');
                    setState(() {
                      isLoading = false;
                    });
                    final fontData = await rootBundle.load('assets/fonts/CordiaUPC_M.ttf');
                    final fontUri = getFontUri(fontData, "font/opentype").toString();
                    // epubController.injectFontIntoWebView(base64Font, "CordiaUPC");
                    // epubController.setFont(font: 'Garuda');
                    // epubController.setFont(font: 'BrowalliaNew');
                    // epubController.setFont(font: 'CordiaUPC');
                    // epubController.setFont(font: 'khand');
                    // epubController.setFontStyle(font: "Khand", styles: "/dist/khand.css");
                    // String base64Font = await fontToBase64("assets/fonts/CordiaUPC_M.ttf");
                    // epubController.injectFontIntoWebView(base64Font, "CordiaUPC");
                    // epubController.webViewController?.reload();
                  },
                  onRelocated: (value) async {
                    print("Reloacted to $value");
                    setState(() {
                      progress = value.progress;
                    });
                    final fontData = await rootBundle.load('assets/fonts/CordiaUPC_M.ttf');
                    final fontUri = getFontUri(fontData, "font/opentype").toString();
                    // String base64Font = await fontToBase64("assets/fonts/CordiaUPC_M.ttf");
                    // epubController.changeFont(base64Font, "CordiaUPC");

                    // String base64Font = await fontToBase64("assets/fonts/Bariol_Regular.otf");
                    // epubController.injectFontIntoWebView(base64Font, "Bariol");
                  },
                  onAnnotationClicked: (cfi) {
                    print("Annotation clicked $cfi");
                  },
                  onTextSelected: (epubTextSelection) {
                    textSelectionCfi = epubTextSelection.selectionCfi;
                    print(textSelectionCfi);
                  },
                  currentChapter: (ch){
                    print('Chapter title : ${ch.title}');
                  },
                ),
                Visibility(
                  visible: isLoading,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              ],
            ),
          ),
        ],
      )),
    );
  }
}
