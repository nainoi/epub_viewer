import 'dart:io';

import 'package:flutter_epub_viewer/src/epub_controller.dart';
import 'package:flutter_epub_viewer/src/helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_epub_viewer/src/utils.dart';

class EpubViewer extends StatefulWidget {
  const EpubViewer({
    super.key,
    required this.epubController,
    required this.epubSource,
    this.initialCfi,
    this.onChaptersLoaded,
    this.onEpubLoaded,
    this.onRelocated,
    this.onTextSelected,
    this.displaySettings,
    this.selectionContextMenu,
    this.onAnnotationClicked,
    this.onTapView,
    this.currentChapter,
    this.onTap,
  });

  ///Epub controller to manage epub
  final EpubController epubController;

  ///Epub source, accepts url, file or assets
  ///opf format is not tested, use with caution
  final EpubSource epubSource;

  ///Initial cfi string to  specify which part of epub to load initially
  ///if null, the first chapter will be loaded
  final String? initialCfi;

  ///Call back when epub is loaded and displayed
  final VoidCallback? onEpubLoaded;

  ///Call back when chapters are loaded
  final ValueChanged<List<EpubChapter>>? onChaptersLoaded;

  ///Call back when epub page changes
  final ValueChanged<EpubLocation>? onRelocated;

  ///Call back when text selection changes
  final ValueChanged<EpubTextSelection>? onTextSelected;

  ///initial display settings
  final EpubDisplaySettings? displaySettings;

  ///Callback for handling annotation click (Highlight and Underline)
  final ValueChanged<String>? onAnnotationClicked;

  final VoidCallback? onTap;

  ///context menu for text selection
  ///if null, the default context menu will be used
  final ContextMenu? selectionContextMenu;

  ///Call back when epub page changes
  final ValueChanged<EpubChapter>? currentChapter;

  final Function()? onTapView;

  @override
  State<EpubViewer> createState() => _EpubViewerState();
}

class _EpubViewerState extends State<EpubViewer> {
  final GlobalKey webViewKey = GlobalKey();

  // late PullToRefreshController pullToRefreshController;
  // late ContextMenu contextMenu;
  var selectedText = '';
  List<EpubChapter> chapters = [];

  InAppWebViewController? webViewController;

  InAppWebViewSettings settings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      javaScriptEnabled: true,
      mediaPlaybackRequiresUserGesture: false,
      transparentBackground: true,
      supportZoom: false,
      allowsInlineMediaPlayback: true,
      disableLongPressContextMenuOnLinks: true,
      disableContextMenu: true,
      iframeAllowFullscreen: true,
      allowsLinkPreview: false,
      verticalScrollBarEnabled: false,
      // disableVerticalScroll: true,
      disableVerticalScroll: true,
      disableHorizontalScroll: false,
      contentInsetAdjustmentBehavior: ScrollViewContentInsetAdjustmentBehavior.SCROLLABLE_AXES,
      disallowOverScroll: false,
      selectionGranularity: SelectionGranularity.CHARACTER);

  // InAppWebViewSettings settings = InAppWebViewSettings(
  //   allowsInlineMediaPlayback: true, // Fix iOS scrolling issues
  //   disableVerticalScroll: false,
  //   disableHorizontalScroll: true, // Prevent accidental horizontal scroll
  //   disallowOverScroll: false, // Prevent rubber-band effect on iOS
  // );

  @override
  void initState() {
    // widget.epubController.initServer();
    super.initState();
  }

  addJavaScriptHandlers() {
    webViewController?.addJavaScriptHandler(
        handlerName: "displayed",
        callback: (data) {
          widget.onEpubLoaded?.call();
        });

    webViewController?.addJavaScriptHandler(
        handlerName: "rendered",
        callback: (data) {
          // widget.onEpubLoaded?.call();
        });

    webViewController?.addJavaScriptHandler(
        handlerName: "chapters",
        callback: (data) async {
          final chapters = await widget.epubController.parseChapters();
          this.chapters = chapters;
          widget.onChaptersLoaded?.call(chapters);
        });

    ///selection handler
    webViewController?.addJavaScriptHandler(
        handlerName: "selection",
        callback: (data) {
          var cfiString = data[0];
          var selectedText = data[1];
          widget.onTextSelected?.call(EpubTextSelection(
              selectedText: selectedText, selectionCfi: cfiString));
        });

    ///search callback
    webViewController?.addJavaScriptHandler(
        handlerName: "search",
        callback: (data) async {
          var searchResult = data[0];
          widget.epubController.searchResultCompleter.complete(
              List<EpubSearchResult>.from(
                  searchResult.map((e) => EpubSearchResult.fromJson(e))));
        });

    ///current cfi callback
    webViewController?.addJavaScriptHandler(
        handlerName: "relocated",
        callback: (data) {
          var location = data[0];
          var loc = EpubLocation.fromJson(location);
          widget.onRelocated?.call(loc);
          if (chapters.isEmpty) {
            chapters = widget.epubController.getChapters();
          }
          EpubChapter? ch = chapters
              .where((e) => e.href == (loc.location?.start?.href ?? ''))
              .firstOrNull;
          if (ch != null) {
            widget.currentChapter?.call(ch);
          }
        });

    webViewController?.addJavaScriptHandler(
        handlerName: "readyToLoad",
        callback: (data) {
          loadBook();
        });

    webViewController?.addJavaScriptHandler(
        handlerName: "displayError",
        callback: (data) {
          // loadBook();
        });

    webViewController?.addJavaScriptHandler(
        handlerName: "markClicked",
        callback: (data) {
          String cfi = data[0];
          widget.onAnnotationClicked?.call(cfi);
        });

    webViewController?.addJavaScriptHandler(
        handlerName: "onTap",
        callback: (data) {
          widget.onTap?.call();
        });

    webViewController?.addJavaScriptHandler(
        handlerName: "epubText",
        callback: (data) {
          var text = data[0].trim();
          var cfi = data[1];
          widget.epubController.pageTextCompleter
              .complete(EpubTextExtractRes(text: text, cfiRange: cfi));
        });
  }

  loadBook() async {
    var data = await widget.epubSource.epubData;
    final displaySettings = widget.displaySettings ?? EpubDisplaySettings();
    String manager = displaySettings.manager.name;
    String flow = displaySettings.flow.name;
    String spread = displaySettings.spread.name;
    bool snap = displaySettings.snap;
    bool allowScripted = displaySettings.allowScriptedContent;
    String cfi = widget.initialCfi ?? "";
    String direction = widget.displaySettings?.defaultDirection.name ??
        EpubDefaultDirection.ltr.name;

    bool useCustomSwipe =
        Platform.isAndroid && !displaySettings.useSnapAnimationAndroid;

    String? backgroundColor =
        widget.displaySettings?.theme?.backgroundColor?.toHex();
    String? foregroundColor =
        widget.displaySettings?.theme?.foregroundColor?.toHex();

    webViewController?.evaluateJavascript(
        source:
            'loadBook([${data.join(',')}], "$cfi", "$manager", "$flow", "$spread", $snap, $allowScripted, "$direction", $useCustomSwipe, "$backgroundColor", "$foregroundColor")');
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      contextMenu: widget.selectionContextMenu,
      key: webViewKey,
      initialFile:
          'packages/flutter_epub_viewer/lib/assets/webpage/html/swipe.html',
      // initialUrlRequest: URLRequest(
      //     url: WebUri(
      //         'http://localhost:8080/html/swipe.html?cfi=${widget.initialCfi ?? ''}&displaySettings=$displaySettings')),
      initialSettings: settings,
      // ..disableVerticalScroll = widget.displaySettings?.snap ?? false,
      // pullToRefreshController: pullToRefreshController,
      onWebViewCreated: (controller) async {
        webViewController = controller;
        widget.epubController.setWebViewController(controller);
        // await loadBook();
        addJavaScriptHandlers();
      },
      onLoadStart: (controller, url) {},
      onPermissionRequest: (controller, request) async {
        return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT);
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        var uri = navigationAction.request.url!;

        if (!["http", "https", "file", "chrome", "data", "javascript", "about"]
            .contains(uri.scheme)) {
          // if (await canLaunchUrl(uri)) {
          //   // Launch the App
          //   await launchUrl(
          //     uri,
          //   );
          //   // and cancel the request
          //   return NavigationActionPolicy.CANCEL;
          // }
        }

        return NavigationActionPolicy.ALLOW;
      },
      gestureRecognizers: {
        Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
      },
      // gestureRecognizers: Set()
      //   ..add(Factory<OneSequenceGestureRecognizer>(
      //       () => EagerGestureRecognizer())),
      onLoadStop: (controller, url) async {
      },
      onReceivedError: (controller, request, error) {},

      onProgressChanged: (controller, progress) {},
      onUpdateVisitedHistory: (controller, url, androidIsReload) {},
      onConsoleMessage: (controller, consoleMessage) {
        if (kDebugMode) {
          debugPrint("JS_LOG: ${consoleMessage.message}");
          // debugPrint(consoleMessage.message);
        }
      },
    );
  }

  @override
  void dispose() {
    webViewController?.dispose();
    super.dispose();
  }
}
