import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chapter_drawer.dart';

class Initial extends StatefulWidget {
  @override
  State<Initial> createState() => _InitialState();
}

class _InitialState extends State<Initial> {
  final epubController = EpubController();

  var textSelectionCfi = '';

  bool isLoading = true;

  bool isFirst = true;

  double sliderValue = 0.5; // Initial slider value

  double progress = 0.0;

  String lastCfi = '';

  // bool _disableScroll = false;

  EpubFlow _epubFlow = EpubFlow.paginated;
  bool _enableSwipe = true;
  EpubTheme _epubTheme = EpubTheme.custom(
      backgroundColor: Colors.black, foregroundColor: Colors.white);
  EpubLocation? _epubLocation;

  // @override
  // void dispose() {
  //   // epubController.webViewController?.dispose();
  //   // epubController.webViewController = null;
  //   super.dispose();
  // }

  void _getLast() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    var last = sharedPreferences.getString('lastcfi');
    setState(() {
      lastCfi = last ?? '';
      isLoading = false;
    });
  }

  @override
  void initState() {
    _getLast();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // drawer: ChapterDrawer(
      //   controller: epubController,
      // ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Reader',
            style: const TextStyle(
                fontSize: 24,
                fontFamily: 'CordiaUPC',
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              if (_enableSwipe) {
                epubController.gotoPage(4);
                setState(() {
                  _enableSwipe = !_enableSwipe;
                  // _epubTheme = EpubTheme.custom(
                  //     backgroundColor: Colors.black,
                  //     foregroundColor: Colors.white);
                  // epubController.setLineHeight(lineHeight: 3);
                });
              } else {
                setState(() {
                  _enableSwipe = !_enableSwipe;
                  // _epubTheme = EpubTheme.dark();
                  // epubController.setLineHeight(lineHeight: 1);
                });
              }
            },
          ),
          IconButton(
            icon: Text(_epubFlow == EpubFlow.paginated ? 'h' : 'v'),
            onPressed: () async {
              if (_epubFlow == EpubFlow.paginated) {
                // epubController.setLineHeight(lineHeight: 3);
                setState(() {
                  _epubFlow = EpubFlow.scrolled;
                  epubController.setFlow(flow: EpubFlow.scrolled);
                  epubController.webViewController?.reload();
                });
              } else {
                // epubController.setLineHeight(lineHeight: 1);
                setState(() {
                  _epubFlow = EpubFlow.paginated;
                  epubController.setFlow(flow: EpubFlow.paginated);
                  epubController.webViewController?.reload();
                });
              }
            },
          ),
        ],
      ),
      body: SafeArea(
          child: Column(
        children: [
          // LinearProgressIndicator(
          //   value: progress,
          //   backgroundColor: Colors.transparent,
          // ),
          if (!isLoading)
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // IgnorePointer(
                  //     ignoring: false,
                  //     child:
                  Container(
                      color: Colors.black,
                      child: EpubViewer(
                        // key: Key('${DateTime.now().microsecond}'),
                        epubSource:
                            EpubSource.fromAsset('assets/epub/etest.epub'),
                        // epubSource: EpubSource.fromUrl(
                        //     'https://vocsyinfotech.in/envato/cc/flutter_ebook/uploads/22566_The-Racketeer---John-Grisham.epub'),
                        // 'https://github.com/IDPF/epub3-samples/releases/download/20230704/accessible_epub_3.epub'),
                        epubController: epubController,
                        initialCfi: lastCfi,
                        disableVerticalScroll: Platform.isAndroid ? false : true,
                        displaySettings: EpubDisplaySettings(
                            flow: _epubFlow,
                            useSnapAnimationAndroid: false,
                            snap: true,
                            theme: _epubTheme,
                            allowScriptedContent: true),
                        selectionContextMenu: ContextMenu(
                          menuItems: [
                            ContextMenuItem(
                              title: "Highlight",
                              id: 1,
                              action: () async {
                                epubController.addHighlight(
                                    cfi: textSelectionCfi);
                              },
                            ),
                          ],
                          settings: ContextMenuSettings(
                              hideDefaultSystemContextMenuItems: true),
                        ),
                        onChaptersLoaded: (chapters) {
                          setState(() {
                            isLoading = false;
                          });
                        },
                        onEpubLoaded: () async {
                          print('Epub loaded');
                          setState(() {
                            isLoading = false;
                          });
                          //epubcfi(/6/14!/4/212/1:0)
                          SharedPreferences sh =
                              await SharedPreferences.getInstance();
                          var last = sh.getString('lastcfi');
                          print('/////////////////////////////////');
                          print(last);
                          print('/////////////////////////////////');
                          epubController.setFont(font: 'CordiaUPC');
                          epubController.setFontSize(fontSize: 30);

                          // var locations = epubController.getLocations();
                          // print(locations);
                        },
                        onRelocated: (value) async {
                          if (isFirst) {
                            setState(() {
                              if (lastCfi.isNotEmpty) {
                                epubController.display(cfi: lastCfi);
                              }
                              isFirst = false;
                            });
                            print("First Reloacted to $value");
                          } else {
                            setState(() {
                              progress = value.progress;
                              _epubLocation = value;
                            });
                            SharedPreferences sh =
                                await SharedPreferences.getInstance();
                            sh.setString('lastcfi', value.startCfi);
                            print(value.startCfi);
                          }

                          // var locations = epubController.getLocations();
                          // print(locations);
                        },
                        onAnnotationClicked: (cfi) {
                          print("Annotation clicked $cfi");
                        },
                        onTextSelected: (epubTextSelection) {
                          textSelectionCfi = epubTextSelection.selectionCfi;
                          print(textSelectionCfi);
                        },
                        currentChapter: (ch) {
                          print('Chapter title : ${ch.title}');
                        },
                        // )
                      )),

                  // Slider (on top of WebView)
                  Positioned(
                      bottom: 0,
                      // Adjust slider position
                      left: 20,
                      right: 20,
                      child: Row(
                        children: [
                          // Expanded(
                          //     child: Container(
                          //         color: Colors.red,
                          //         child: Slider(
                          //           value: sliderValue,
                          //           onChangeEnd: (value) {
                          //             // epubController.next();
                          //           },
                          //           onChanged: (value) {
                          //             // epubController.setSnap(enable: true);
                          //             // epubController.enableSwipe();
                          //             // epubController.webViewController?.reload();
                          //             setState(() {
                          //               sliderValue = value;
                          //             });
                          //           },
                          //         ))),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '${_epubLocation?.location?.start?.displayed?.page}/${_epubLocation?.location?.start?.displayed?.total}',
                                style: TextStyle(color: Colors.red),
                              )
                            ],
                          )
                        ],
                      )),
                ],
              ),
            ),
        ],
      )),
    );
  }
}
