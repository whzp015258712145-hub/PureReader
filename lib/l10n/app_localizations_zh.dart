// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'PureReader';

  @override
  String get open => '打开书籍';

  @override
  String get settings => '阅读设置';

  @override
  String get toc => '目录';

  @override
  String get fontSize => '字号大小';

  @override
  String get lineHeight => '行间距';

  @override
  String get margin => '页边距';

  @override
  String get theme => '外观主题';

  @override
  String get lang => '语言设定';

  @override
  String get appearance => '外观设置';

  @override
  String get fontFamily => '字体选择';

  @override
  String get zoom => '视图缩放';

  @override
  String get customTheme => '自定义颜色';

  @override
  String get ok => '确定';

  @override
  String get tocNotAvailable => '暂无目录';
}
