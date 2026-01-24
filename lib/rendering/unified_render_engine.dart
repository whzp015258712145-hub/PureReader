import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart';
import 'package:pdfx/pdfx.dart' hide DefaultBuilderOptions;

import '../models/ebook_content.dart';
import '../models/ebook_format.dart';
import '../reader_state.dart';
import 'pdf_reader_widget.dart';
import 'txt_reader_widget.dart';

class UnifiedRenderEngine extends StatelessWidget {
  final EbookContent content;
  final ReaderConfig config;

  const UnifiedRenderEngine({
    super.key,
    required this.content,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: _buildEngine(context),
    );
  }

  Widget _buildEngine(BuildContext context) {
    // Shared fallback fonts for international characters
    final List<String> fontFallbacks = [
      '.AppleSystemUIFont', // macOS/iOS
      'PingFang SC',       // Chinese
      'Hiragino Sans',     // Japanese
      'Microsoft YaHei',   // Windows Chinese
      'Arial',             // Global fallback
    ];

    switch (content.format) {
      case EbookFormat.epub:
        final isNight = config.theme.id == 'night';
        
        // Prepare base text style for EPUB
        final baseStyle = TextStyle(
          color: config.theme.textColor,
          fontSize: config.fontSize,
          fontFamily: config.fontFamily,
          fontFamilyFallback: fontFallbacks,
          height: config.lineHeight,
        );

        Widget epubView = EpubView(
          controller: content.controller as EpubController,
          builders: EpubViewBuilders<DefaultBuilderOptions>(
            options: DefaultBuilderOptions(
              textStyle: baseStyle,
            ),
            loaderBuilder: (context) => const Center(
              child: CupertinoActivityIndicator(),
            ),
          ),
        );

        return Container(
          color: config.theme.backgroundColor,
          child: epubView,
        );
      case EbookFormat.pdf:
        return PdfReaderWidget(
          document: content.controller as PdfDocument,
          config: config,
        );
      case EbookFormat.txt:
        return TxtReaderWidget(
          pages: content.pages ?? [],
          config: config,
        );
      case EbookFormat.mobi:
      case EbookFormat.azw3:
        if (content.textContent != null) {
           final pages = content.pages ?? [content.textContent!];
           return TxtReaderWidget(pages: pages, config: config);
        }
        return const Center(
          child: Text(
            'MOBI/AZW3 viewing is partially supported (parsing only). \nRendering requires HTML conversion.',
            textAlign: TextAlign.center,
          ),
        );
      case EbookFormat.unknown:
        return const Center(child: Text('Unknown format'));
    }
  }
}