import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epub_view/epub_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:app_links/app_links.dart';
import 'package:window_manager/window_manager.dart';
import 'reader_state.dart';
import 'models/reader_theme.dart';
import 'utils/l10n_extension.dart';

import 'models/ebook_content.dart';
import 'models/ebook_format.dart';
import 'formats/file_format_detector.dart';
import 'parsers/ebook_parser_factory.dart';
import 'rendering/unified_render_engine.dart';
import 'startup/startup_optimizer.dart';
import 'cache/cache_manager.dart';
import 'error/error_recovery_manager.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String? initialPath;
  const HomeScreen({super.key, this.initialPath});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  EbookContent? _ebookContent;
  bool _isLoading = false;
  double _baseScale = 1.0;
  final TransformationController _transformationController = TransformationController();
  
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  static const _channel = MethodChannel('com.purereader.app/file_open');
  String? _currentLoadedPath;

  @override
  void initState() {
    super.initState();
    StartupOptimizer.initialize();
    
    // Initialize transformation controller with current scale
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scale = 1.0; // Matrix starts at 1.0, fontSize handles logic
      _transformationController.value = Matrix4.identity()..scale(scale);
    });

    if (widget.initialPath != null) {
      _loadBook(widget.initialPath!);
    }
    _initNativeFileListener();
    _initMethodChannel();
  }

  void _initMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == "onOpenFile") {
        final String path = call.arguments as String;
        _loadBook(path);
      }
    });
  }

  void _initNativeFileListener() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _loadBook(uri.toFilePath());
    });
  }

  Future<void> _loadBook(String path) async {
    if (_currentLoadedPath == path) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final cached = await CacheManager.getCachedContent(path);
      if (cached != null) {
        setState(() {
          _ebookContent = cached;
          _currentLoadedPath = path;
          _isLoading = false;
        });
        return;
      }

      final format = await FileFormatDetector.detectFormat(path);
      if (format == EbookFormat.unknown) {
         throw Exception('Unknown file format');
      }

      final parser = EbookParserFactory.createParser(format);
      final content = await parser.parse(path);
      
      await CacheManager.cacheContent(path, content);

      setState(() {
        _ebookContent = content;
        _currentLoadedPath = path;
        _isLoading = false;
      });
    } catch (e, stack) {
      if (mounted) {
        ErrorRecoveryManager.handleError(context, e, stackTrace: stack);
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleManualOpen() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'pdf', 'txt', 'mobi', 'azw3'],
    );
    if (result != null && result.files.single.path != null) {
      _loadBook(result.files.single.path!);
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _transformationController.dispose();
    if (_ebookContent?.controller is EpubController) {
      (_ebookContent!.controller as EpubController).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(readerConfigProvider);
    final theme = config.theme;

    ref.listen(openFileRequestProvider, (previous, next) {
      if (next != null) {
        _loadBook(next);
        Future.microtask(() => ref.read(openFileRequestProvider.notifier).state = null);
      }
    });

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Column(
        children: [
          DragToMoveArea(
            child: Container(
              height: 38,
              color: Colors.transparent,
            ),
          ),
          Expanded(
            child: _ebookContent == null 
              ? _buildMainContent(config, theme)
              : Row(
                  children: [
                    _buildPersistentSidebar(context, config, theme),
                    Expanded(
                      child: ClipRect(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Listener(
                              onPointerSignal: (pointerSignal) {
                                if (pointerSignal is PointerScrollEvent &&
                                    RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.controlLeft)) {
                                  // For mouse wheel zoom, we update logical font size directly
                                  final delta = pointerSignal.scrollDelta.dy / 100;
                                  ref.read(readerConfigProvider.notifier).updateFontSize(config.fontSize - delta);
                                }
                              },
                              child: InteractiveViewer(
                                transformationController: _transformationController,
                                minScale: 0.5,
                                maxScale: 5.0,
                                constrained: false,
                                onInteractionUpdate: (details) {
                                  // Performance: Visual scaling only
                                },
                                onInteractionEnd: (details) {
                                  final visualScale = _transformationController.value.getMaxScaleOnAxis();
                                  if ((visualScale - 1.0).abs() > 0.01) {
                                    ref.read(readerConfigProvider.notifier).updateFontSize(config.fontSize * visualScale);
                                    _transformationController.value = Matrix4.identity();
                                  }
                                },
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return FadeTransition(opacity: animation, child: child);
                                  },
                                  child: SizedBox(
                                    key: ValueKey(config.fontSize),
                                    width: constraints.maxWidth,
                                    height: constraints.maxHeight,
                                    child: _buildMainContent(config, theme),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersistentSidebar(BuildContext context, ReaderConfig config, ReaderTheme theme) {
    return Container(
      width: 280,
      color: theme.uiOverlayColor.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.toc, 
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: theme.textColor,
                    height: 1.2,
                  ),
                  strutStyle: const StrutStyle(
                    forceStrutHeight: true,
                    height: 1.2,
                    leading: 0.3,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.settings_outlined, color: theme.textColor.withOpacity(0.6), size: 18),
                  onPressed: () => _showAppearanceSettings(context, theme),
                ),
              ],
            ),
          ),
          Expanded(child: _buildTOCView(config, theme)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTOCView(ReaderConfig config, ReaderTheme theme) {
    if (_ebookContent?.format == EbookFormat.epub && _ebookContent?.controller is EpubController) {
      return EpubViewTableOfContents(
        controller: _ebookContent!.controller as EpubController,
        itemBuilder: (context, index, chapter, itemCount) => InkWell(
          onTap: () {
            // Reset zoom/translation when navigating to a new section
            _transformationController.value = Matrix4.identity();
            (_ebookContent!.controller as EpubController).scrollTo(index: chapter.startIndex);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              chapter.title?.trim() ?? 'Chapter $index',
              style: TextStyle(
                fontSize: 14, 
                color: theme.textColor.withOpacity(0.9),
                height: 1.2,
              ),
              strutStyle: const StrutStyle(
                forceStrutHeight: true,
                height: 1.2,
                leading: 0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }
    return Center(
      child: Text(
        context.l10n.tocNotAvailable, 
        style: TextStyle(color: theme.textColor.withOpacity(0.3)),
      ),
    );
  }

  void _showAppearanceSettings(BuildContext context, ReaderTheme theme) {
    showDialog(
      context: context,
      builder: (context) => _AppearanceDialog(theme: theme),
    );
  }

  Widget _buildMainContent(ReaderConfig config, ReaderTheme theme) {
    if (_isLoading) {
      return Center(child: CupertinoActivityIndicator(color: theme.textColor));
    }
    if (_ebookContent == null) {
      return _buildEmptyState(theme);
    }
    return UnifiedRenderEngine(
      content: _ebookContent!,
      config: config,
    );
  }

  Widget _buildEmptyState(ReaderTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: 0.8,
            child: Icon(
              CupertinoIcons.book, 
              size: 80, 
              color: theme.textColor.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 20),
          CupertinoButton(
            onPressed: _handleManualOpen,
            color: theme.accentColor,
            borderRadius: BorderRadius.circular(8),
            child: Text(
              context.l10n.open,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceDialog extends ConsumerWidget {
  final ReaderTheme theme;

  const _AppearanceDialog({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(readerConfigProvider);
    final notifier = ref.read(readerConfigProvider.notifier);

    return AlertDialog(
      backgroundColor: theme.backgroundColor,
      title: Text(context.l10n.appearance, style: TextStyle(color: theme.textColor)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.fontFamily, style: TextStyle(color: theme.textColor.withOpacity(0.7), fontSize: 12)),
            DropdownButton<String>(
              value: config.fontFamily,
              dropdownColor: theme.backgroundColor,
              items: ['.SF Pro Text', 'Serif', 'Courier'].map((f) => DropdownMenuItem(
                value: f,
                child: Text(f, style: TextStyle(color: theme.textColor, fontFamily: f)),
              )).toList(),
              onChanged: (v) => v != null ? notifier.updateFontFamily(v) : null,
            ),
            const SizedBox(height: 20),
            _buildControl(context.l10n.fontSize, config.fontSize, 12, 40, (v) => notifier.updateFontSize(v)),
            _buildControl(context.l10n.lineHeight, config.lineHeight, 1.0, 2.5, (v) => notifier.updateLineHeight(v)),
            const SizedBox(height: 20),
            Text(context.l10n.customTheme, style: TextStyle(color: theme.textColor.withOpacity(0.7), fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              children: [
                _colorBox(const Color(0xFFF0E4D7), const Color(0xFF333333), notifier),
                _colorBox(const Color(0xFF2D3033), const Color(0xFFE0E0E0), notifier),
                _colorBox(const Color(0xFFE8D5B5), const Color(0xFF4B3621), notifier),
              ],
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.ok)),
      ],
    );
  }

  Widget _colorBox(Color bg, Color text, ReaderNotifier notifier) {
    return GestureDetector(
      onTap: () => notifier.setCustomTheme(bg, text),
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(child: Text('A', style: TextStyle(color: text, fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _buildControl(String label, double val, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: theme.textColor.withOpacity(0.7), fontSize: 12)),
        Slider(
          value: val,
          min: min,
          max: max,
          activeColor: theme.accentColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
