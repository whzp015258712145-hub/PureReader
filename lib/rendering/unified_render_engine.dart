import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart' hide Image;
import 'package:flutter_html/flutter_html.dart';
import 'package:pdfx/pdfx.dart' hide DefaultBuilderOptions, Image;

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
        // 1. Pre-calculate styles once per theme change to save CPU during scrolling
        final headingStyle = Style(
          backgroundColor: config.theme.uiOverlayColor,
          color: config.theme.textColor,
          padding: HtmlPaddings.symmetric(vertical: 20, horizontal: 10),
          lineHeight: const LineHeight(1.5),
          width: Width(100, Unit.percent),
        );

        final htmlStyle = {
          'html': Style(
            padding: HtmlPaddings.only(
              top: 8,
              right: 16,
              bottom: 8,
              left: 16,
            ),
          ).merge(Style.fromTextStyle(TextStyle(
            color: config.theme.textColor,
            fontSize: config.fontSize,
            fontFamily: config.fontFamily,
            fontFamilyFallback: fontFallbacks,
            height: config.lineHeight,
          ))),
          'h1, h2, h3, h4, h5, h6, .title, .header': headingStyle,
        };

        Widget epubView = EpubView(
          controller: content.controller as EpubController,
          builders: EpubViewBuilders<DefaultBuilderOptions>(
            options: DefaultBuilderOptions(
              textStyle: TextStyle(
                color: config.theme.textColor,
                fontSize: config.fontSize,
                fontFamily: config.fontFamily,
                fontFamilyFallback: fontFallbacks,
                height: config.lineHeight,
              ),
            ),
            chapterDividerBuilder: (chapter) => Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: config.theme.uiOverlayColor,
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                chapter.Title ?? '',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: config.theme.textColor,
                  height: 1.4,
                  fontFamily: config.fontFamily,
                  fontFamilyFallback: fontFallbacks,
                ),
                textHeightBehavior: const TextHeightBehavior(
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ),
            chapterBuilder: (context, builders, document, chapters, paragraphs, index, chapterIndex, paragraphIndex, onExternalLinkPressed) {
              if (paragraphs.isEmpty || index >= paragraphs.length) {
                return const SizedBox.shrink();
              }

              final paragraph = paragraphs[index];

              return Column(
                key: ValueKey('para_$index'), // Help Flutter reuse widgets
                children: <Widget>[
                  if (chapterIndex >= 0 && paragraphIndex == 0)
                    builders.chapterDividerBuilder(chapters[chapterIndex]),
                  Html(
                    data: paragraph.element.outerHtml,
                    onLinkTap: (href, _, __) => onExternalLinkPressed(href!),
                    style: htmlStyle,
                    extensions: [
                      TagExtension(
                        tagsToExtend: const {"img"},
                        builder: (imageContext) {
                          final url = imageContext.attributes['src']?.replaceAll('../', '');
                          if (url == null) return const SizedBox.shrink();
                          final imgContent = document.Content?.Images?[url]?.Content;
                          if (imgContent == null) return const SizedBox.shrink();
                          return Image(
                            image: MemoryImage(Uint8List.fromList(imgContent)),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              );
            },
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