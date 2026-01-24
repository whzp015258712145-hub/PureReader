import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';

extension L10nExtension on BuildContext {
  // 返回非空对象以满足编译器，如果资源未就绪则返回 null 的断言检查将由 UI 层兜底
  AppLocalizations get l10n {
    final instance = AppLocalizations.of(this);
    if (instance == null) {
      // 这是一个临时的紧急兜底，防止在资源加载瞬间的 Null 指针闪退
      // 在生产环境下，MaterialApp 应该保证在进入 build 时资源已就绪
      throw FlutterError('AppLocalizations not found in context. Ensure MaterialApp is configured correctly.');
    }
    return instance;
  }
}