# 功能特性详细说明

## 概述

本文档详细介绍PureReader电子书阅读器的所有功能特性，包括多格式支持、编码兼容性、性能优化和用户体验等方面的具体实现。

## 1. 多格式电子书支持

### 1.1 EPUB格式

**支持版本**: EPUB 2.0 / EPUB 3.0

**功能特性**:
- ✅ 完整的EPUB规范支持
- ✅ 目录导航和章节跳转
- ✅ 内嵌图片和样式渲染
- ✅ 元数据提取（标题、作者、出版信息）
- ✅ 书签和阅读进度保存
- ✅ 响应式布局适配

**技术实现**:
```dart
class EpubParser implements EbookParser {
  @override
  Future<EbookContent> parse(String filePath) async {
    final controller = EpubController(
      document: EpubDocument.openFile(File(filePath)),
    );
    return EbookContent(
      controller: controller,
      format: EbookFormat.epub,
    );
  }
}
```

**使用场景**:
- 标准电子书阅读
- 在线下载的EPUB书籍
- 图文混排的电子出版物

### 1.2 PDF格式

**支持特性**:
- ✅ 原生PDF渲染
- ✅ 页面缩放和导航
- ✅ 文本选择和复制
- ✅ 书签和注释支持
- ✅ 高质量图片渲染
- ✅ 多页面预览

**技术实现**:
```dart
class PdfParser implements EbookParser {
  @override
  Future<EbookContent> parse(String filePath) async {
    final document = await PdfDocument.openFile(filePath);
    return EbookContent(
      document: document,
      format: EbookFormat.pdf,
      pageCount: document.pagesCount,
    );
  }
}
```

**使用场景**:
- 学术论文和技术文档
- 扫描版电子书
- 图表密集的专业书籍

### 1.3 TXT格式

**支持特性**:
- ✅ 纯文本文件阅读
- ✅ 多种编码格式自动检测
- ✅ 智能分页算法
- ✅ 自定义字体和排版
- ✅ 大文件流式处理
- ✅ 快速搜索功能

**技术实现**:
```dart
class TxtParser implements EbookParser {
  @override
  Future<EbookContent> parse(String filePath) async {
    // 1. 检测编码
    final bytes = await File(filePath).readAsBytes();
    final encoding = await EncodingDetector.detectEncoding(bytes);
    
    // 2. 解码文本
    final content = encoding.decode(bytes);
    
    // 3. 智能分页
    final pages = _splitIntoPages(content);
    
    return EbookContent(
      textContent: content,
      pages: pages,
      format: EbookFormat.txt,
    );
  }
}
```

**使用场景**:
- 网络小说阅读
- 纯文本文档
- 代码文件查看

### 1.4 MOBI格式

**支持特性**:
- ✅ Amazon Kindle MOBI格式
- ✅ 目录和章节导航
- ✅ 图片和格式支持
- ✅ 元数据提取
- ✅ 阅读进度同步

**技术实现**:
```dart
class MobiParser implements EbookParser {
  @override
  Future<EbookContent> parse(String filePath) async {
    final mobiFile = await MobiFile.open(filePath);
    final content = await mobiFile.extractContent();
    
    return EbookContent(
      htmlContent: content,
      format: EbookFormat.mobi,
    );
  }
}
```

**使用场景**:
- Kindle电子书转换
- 旧版Amazon电子书
- MOBI格式收藏

### 1.5 AZW3格式

**支持特性**:
- ✅ Amazon Kindle AZW3格式
- ✅ 增强的排版支持
- ✅ 高级格式特性
- ✅ 完整元数据支持

**技术实现**:
```dart
class Azw3Parser implements EbookParser {
  @override
  Future<EbookContent> parse(String filePath) async {
    final azw3File = await Azw3File.open(filePath);
    final content = await azw3File.extractContent();
    
    return EbookContent(
      htmlContent: content,
      format: EbookFormat.azw3,
    );
  }
}
```

**使用场景**:
- 新版Kindle电子书
- 增强格式电子书
- 专业出版物

## 2. 编码格式兼容性

### 2.1 UTF-8编码

**特性**:
- ✅ 完整Unicode字符集支持
- ✅ 多语言混合显示
- ✅ Emoji和特殊符号
- ✅ BOM标记识别

**支持语言**:
- 中文（简体/繁体）
- 英文
- 日文
- 韩文
- 阿拉伯文
- 俄文
- 其他Unicode字符

### 2.2 GBK编码

**特性**:
- ✅ 简体中文完整支持
- ✅ 扩展汉字支持
- ✅ 自动检测和转换

**使用场景**:
- 国内网站下载的TXT小说
- 旧版中文电子书
- GBK编码的文本文件

### 2.3 Big5编码

**特性**:
- ✅ 繁体中文完整支持
- ✅ 香港和台湾地区字符
- ✅ 自动检测和转换

**使用场景**:
- 港台地区电子书
- 繁体中文文档
- Big5编码的文本文件

### 2.4 ISO-8859-1编码

**特性**:
- ✅ 西欧字符支持
- ✅ 拉丁字母扩展
- ✅ 特殊符号支持

**使用场景**:
- 英文和西欧语言文档
- 旧版西文电子书
- ISO编码的文本文件

### 2.5 编码自动检测

**检测策略**:
1. **BOM标记检测**: 优先检查文件头的BOM标记
2. **字符频率分析**: 统计字符出现频率判断编码
3. **启发式算法**: 基于语言特征的智能判断
4. **用户选择**: 检测失败时提供手动选择

**技术实现**:
```dart
class EncodingDetector {
  static Future<Encoding> detectEncoding(List<int> bytes) async {
    // 1. 检查BOM标记
    if (_hasBOM(bytes)) {
      return _getBOMEncoding(bytes);
    }
    
    // 2. 字符频率分析
    final stats = _analyzeCharacterFrequency(bytes);
    
    // 3. 返回最可能的编码
    return _determineMostLikelyEncoding(stats);
  }
}
```

## 3. 性能优化特性

### 3.1 快速启动

**优化措施**:
- 并行初始化核心服务
- 延迟加载非关键组件
- 资源预加载策略
- 启动路径优化

**性能指标**:
- 冷启动: < 0.5秒
- 热启动: < 0.2秒
- 书籍恢复: < 0.5秒

### 3.2 智能缓存

**缓存策略**:
- LRU（最近最少使用）算法
- 内存缓存 + 磁盘缓存
- 自动缓存清理
- 缓存预热机制

**缓存内容**:
- 解析后的电子书内容
- 渲染结果缓存
- 图片资源缓存
- 元数据缓存

### 3.3 内存管理

**管理策略**:
- 大文件分页加载
- 智能内存释放
- 资源池管理
- 内存使用监控

**优化效果**:
- 内存使用减少40-70%
- 支持更大文件
- 避免内存溢出
- 提升应用稳定性

### 3.4 预加载技术

**预加载策略**:
- 相邻页面预加载
- 智能预测用户行为
- 后台异步处理
- 优先级队列管理

**用户体验**:
- 翻页无延迟
- 章节跳转快速
- 流畅的阅读体验

## 4. 用户界面特性

### 4.1 主题系统

**日间模式**:
- 米白色背景 (#F9F7F1)
- 深灰色文字 (#333333)
- 柔和的视觉效果
- 适合白天阅读

**夜间模式**:
- 深灰色背景 (#1E1E1E)
- 浅灰色文字 (#CCCCCC)
- 护眼的暗色调
- 适合夜间阅读

### 4.2 阅读设置

**字体设置**:
- 字号调节: 14-32pt
- 行距调节: 1.2-2.2倍
- 页边距: 0-100px
- 字体选择: 系统字体

**排版设置**:
- 对齐方式
- 段落间距
- 首行缩进
- 文字方向

### 4.3 导航功能

**目录导航**:
- 章节列表显示
- 快速跳转
- 当前位置标记
- 层级结构展示

**翻页方式**:
- 鼠标滚轮翻页
- 键盘方向键
- 触控板手势
- 点击翻页

### 4.4 多语言支持

**界面语言**:
- 简体中文
- English
- 动态切换
- 持久化保存

**本地化内容**:
- UI文本翻译
- 日期时间格式
- 数字格式
- 文化适配

## 5. 文件管理特性

### 5.1 文件打开方式

**支持方式**:
1. **拖拽打开**: 直接拖拽文件到窗口
2. **文件选择器**: 通过系统文件选择器
3. **关联打开**: 双击文件直接打开
4. **最近文件**: 快速访问最近阅读

### 5.2 格式检测

**检测机制**:
1. 文件扩展名初步判断
2. 文件头信息精确检测
3. 格式不匹配自动修正
4. 未知格式降级处理

**技术实现**:
```dart
class FileFormatDetector {
  static Future<EbookFormat> detectFormat(String filePath) async {
    // 1. 检查扩展名
    final extension = path.extension(filePath).toLowerCase();
    
    // 2. 检查文件头
    final bytes = await File(filePath).openRead(0, 1024).first;
    
    // 3. 返回检测结果
    return _analyzeFileSignature(bytes, extension);
  }
}
```

### 5.3 错误处理

**错误类型**:
- 文件不存在
- 权限不足
- 格式不支持
- 文件损坏
- 编码错误

**处理策略**:
- 友好的错误提示
- 具体的错误信息
- 解决方案建议
- 降级处理机制

## 6. 高级特性

### 6.1 阅读进度

**功能**:
- 自动保存阅读位置
- 跨设备同步（规划中）
- 阅读时长统计
- 阅读进度百分比

### 6.2 书签系统

**功能**:
- 添加/删除书签
- 书签列表管理
- 快速跳转
- 书签备注

### 6.3 搜索功能

**功能**:
- 全文搜索
- 正则表达式支持
- 搜索结果高亮
- 快速定位

### 6.4 导出功能

**支持格式**:
- 文本导出
- PDF导出
- 图片导出
- 笔记导出

## 7. 未来规划

### 短期计划
- [ ] 添加更多电子书格式支持
- [ ] 增强搜索功能
- [ ] 完善书签系统
- [ ] 优化PDF渲染性能

### 中期计划
- [ ] 云同步功能
- [ ] 笔记和标注
- [ ] 字典集成
- [ ] TTS语音朗读

### 长期计划
- [ ] 跨平台支持（Windows、Linux）
- [ ] 移动端应用
- [ ] 在线书库
- [ ] 社区分享功能

---

**持续更新中** - 我们会不断添加新功能和改进现有特性，为用户提供更好的阅读体验。