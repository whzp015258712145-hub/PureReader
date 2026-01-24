import 'package:flutter/material.dart';
import '../reader_state.dart';

class TxtReaderWidget extends StatelessWidget {
  final List<String> pages;
  final ReaderConfig config;

  const TxtReaderWidget({
    super.key,
    required this.pages,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> fontFallbacks = [
      '.AppleSystemUIFont',
      'PingFang SC',
      'Hiragino Sans',
      'Microsoft YaHei',
      'Arial',
    ];

    return Container(
      color: config.theme.backgroundColor,
      child: SelectionArea(
        child: ListView.builder(
          itemCount: pages.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.all(config.padding),
              child: Text(
                pages[index],
                style: TextStyle(
                  fontSize: config.fontSize,
                  height: config.lineHeight,
                  color: config.theme.textColor,
                  fontFamily: config.fontFamily,
                  fontFamilyFallback: fontFallbacks,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
