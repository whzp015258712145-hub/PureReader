import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../reader_state.dart';

class PdfReaderWidget extends StatefulWidget {
  final PdfDocument document;
  final ReaderConfig config;

  const PdfReaderWidget({
    super.key,
    required this.document,
    required this.config,
  });

  @override
  State<PdfReaderWidget> createState() => _PdfReaderWidgetState();
}

class _PdfReaderWidgetState extends State<PdfReaderWidget> {
  late PdfController _pdfController;

  @override
  void initState() {
    super.initState();
    // Initialize controller with the existing document
    _pdfController = PdfController(
      document: Future.value(widget.document),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.config.theme.backgroundColor,
      child: PdfView(
        controller: _pdfController,
        scrollDirection: Axis.vertical,
        backgroundDecoration: BoxDecoration(
          color: widget.config.theme.backgroundColor,
        ),
      ),
    );
  }
}
