import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:app_links/app_links.dart';
import 'package:file_picker/file_picker.dart';
import 'home_screen.dart';
import 'reader_state.dart';
import 'startup/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final appLinks = AppLinks();
  final Uri? initialUri = await appLinks.getInitialLink();
  final String? initialPath = initialUri?.toFilePath();

  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1100, 800),
    minimumSize: Size(900, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: "PureReader",
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    ProviderScope(
      child: PureReaderApp(initialPath: initialPath),
    ),
  );
}

class PureReaderApp extends ConsumerStatefulWidget {
  final String? initialPath;
  const PureReaderApp({super.key, this.initialPath});

  @override
  ConsumerState<PureReaderApp> createState() => _PureReaderAppState();
}

class _PureReaderAppState extends ConsumerState<PureReaderApp> {
  bool _showSplash = true;

  List<PlatformMenuItem> _buildAppMenu(bool isZh) {
    final items = <PlatformMenuItem>[];
    if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.about)) {
      items.add(const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about));
    }
    if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.quit)) {
      items.add(const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit));
    }
    
    if (items.isEmpty) return [];
    return [
      PlatformMenuItemGroup(members: items),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(readerConfigProvider);
    final isZh = config.locale.languageCode == 'zh';

    final List<PlatformMenu> menus = [
      PlatformMenu(
        label: 'PureReader',
        menus: _buildAppMenu(isZh),
      ),
      PlatformMenu(
        label: isZh ? '文件' : 'File',
        menus: [
          PlatformMenuItem(
            label: isZh ? '打开...' : 'Open...',
            shortcut: const SingleActivator(LogicalKeyboardKey.keyO, meta: true),
            onSelected: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['epub', 'pdf', 'txt', 'mobi', 'azw3'],
              );
              if (result != null && result.files.single.path != null) {
                ref.read(openFileRequestProvider.notifier).state = result.files.single.path;
              }
            },
          ),
        ],
      ),
      PlatformMenu(
        label: isZh ? '编码' : 'Encoding',
        menus: [
          PlatformMenuItem(
            label: 'Auto (Detect)',
            onSelected: () => ref.read(openFileWithEncodingProvider.notifier).state = 'RELOAD|auto',
          ),
          PlatformMenuItem(
            label: 'UTF-8 (Universal)',
            onSelected: () => ref.read(openFileWithEncodingProvider.notifier).state = 'RELOAD|utf-8',
          ),
          PlatformMenuItem(
            label: 'GBK (Chinese)',
            onSelected: () => ref.read(openFileWithEncodingProvider.notifier).state = 'RELOAD|gbk',
          ),
          PlatformMenuItem(
            label: 'Shift-JIS (Japanese)',
            onSelected: () => ref.read(openFileWithEncodingProvider.notifier).state = 'RELOAD|shift_jis',
          ),
          PlatformMenuItem(
            label: 'Windows-1252 (Western)',
            onSelected: () => ref.read(openFileWithEncodingProvider.notifier).state = 'RELOAD|windows-1252',
          ),
          PlatformMenuItem(
            label: 'Windows-1251 (Cyrillic)',
            onSelected: () => ref.read(openFileWithEncodingProvider.notifier).state = 'RELOAD|windows-1251',
          ),
        ],
      ),
      PlatformMenu(
        label: isZh ? '视图' : 'View',
        menus: [
          PlatformMenuItem(
            label: isZh ? '放大' : 'Zoom In',
            shortcut: const SingleActivator(LogicalKeyboardKey.equal, meta: true),
            onSelected: () {
              final notifier = ref.read(readerConfigProvider.notifier);
              notifier.updateFontSize(config.fontSize * 1.1);
            },
          ),
          PlatformMenuItem(
            label: isZh ? '缩小' : 'Zoom Out',
            shortcut: const SingleActivator(LogicalKeyboardKey.minus, meta: true),
            onSelected: () {
              final notifier = ref.read(readerConfigProvider.notifier);
              notifier.updateFontSize(config.fontSize * 0.9);
            },
          ),
          PlatformMenuItem(
            label: isZh ? '实际大小' : 'Actual Size',
            shortcut: const SingleActivator(LogicalKeyboardKey.digit0, meta: true),
            onSelected: () {
              final notifier = ref.read(readerConfigProvider.notifier);
              notifier.updateFontSize(18.0); // Reset to default base size
            },
          ),
          if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.toggleFullScreen))
            const PlatformMenuItemGroup(members: [
              PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.toggleFullScreen),
            ]),
        ],
      ),
      PlatformMenu(
        label: isZh ? '外观主题' : 'Theme',
        menus: [
          PlatformMenuItem(
            label: isZh ? '日光' : 'Day',
            onSelected: () => ref.read(readerConfigProvider.notifier).setTheme('day'),
          ),
          PlatformMenuItem(
            label: isZh ? '夜间' : 'Night',
            onSelected: () => ref.read(readerConfigProvider.notifier).setTheme('night'),
          ),
          PlatformMenuItem(
            label: isZh ? '纸感' : 'Muji',
            onSelected: () => ref.read(readerConfigProvider.notifier).setTheme('muji'),
          ),
          PlatformMenuItem(
            label: isZh ? '护眼' : 'Forest',
            onSelected: () => ref.read(readerConfigProvider.notifier).setTheme('forest'),
          ),
        ],
      ),
      PlatformMenu(
        label: isZh ? '语言' : 'Language',
        menus: [
          PlatformMenuItem(
            label: 'English',
            onSelected: () => ref.read(readerConfigProvider.notifier).setLocale('en'),
          ),
          PlatformMenuItem(
            label: '中文',
            onSelected: () => ref.read(readerConfigProvider.notifier).setLocale('zh'),
          ),
        ],
      ),
    ];

    final windowMenuItems = <PlatformMenuItem>[];
    if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.minimizeWindow)) {
      windowMenuItems.add(const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.minimizeWindow));
    }
    if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.zoomWindow)) {
      windowMenuItems.add(const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.zoomWindow));
    }

    if (windowMenuItems.isNotEmpty) {
      menus.add(PlatformMenu(
        label: isZh ? '窗口' : 'Window',
        menus: windowMenuItems,
      ));
    }

    return PlatformMenuBar(
      menus: menus,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PureReader',
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: config.fontFamily,
        ),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: config.locale,
        home: _showSplash 
          ? SplashScreen(onAnimationComplete: () => setState(() => _showSplash = false))
          : HomeScreen(initialPath: widget.initialPath),
      ),
    );
  }
}
