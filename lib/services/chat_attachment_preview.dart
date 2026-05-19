import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../core/api_config.dart';
import '../widgets/app_snackbar.dart';

bool chatAttachmentIsImage({
  String? attachmentType,
  required String attachmentUrl,
  String? attachmentName,
}) {
  if (attachmentType == 'image') return true;
  final hint = (attachmentName ?? attachmentUrl).toLowerCase();
  return hint.endsWith('.jpg') ||
      hint.endsWith('.jpeg') ||
      hint.endsWith('.png') ||
      hint.endsWith('.webp') ||
      hint.endsWith('.heic');
}

String _safeFilename(String name) {
  final base = name.split('/').last.split('\\').last;
  if (base.isEmpty) return 'attachment';
  return base.replaceAll(RegExp(r'[^\w.\-()]'), '_');
}

/// Opens an in-app image preview or downloads and opens other file types.
Future<void> previewChatAttachment(
  BuildContext context, {
  required String attachmentUrl,
  String? attachmentName,
  String? attachmentType,
}) async {
  final url = fullImageUrl(attachmentUrl);
  if (url.isEmpty) return;

  if (chatAttachmentIsImage(
    attachmentType: attachmentType,
    attachmentUrl: attachmentUrl,
    attachmentName: attachmentName,
  )) {
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => _ChatImagePreviewPage(
          imageUrl: url,
          title: attachmentName,
        ),
      ),
    );
    return;
  }

  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const PopScope(
      canPop: false,
      child: Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading file…'),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('Could not load file (${res.statusCode})');
    }
    final dir = await getTemporaryDirectory();
    final name = _safeFilename(
      attachmentName ?? attachmentUrl.split('/').last,
    );
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(res.bodyBytes);

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done && context.mounted) {
      final msg = result.message.trim().isEmpty
          ? 'No app available to open this file.'
          : result.message;
      context.showAppSnackBar(msg);
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      context.showAppSnackBar('Could not open file: $e');
    }
  }
}

class _ChatImagePreviewPage extends StatelessWidget {
  const _ChatImagePreviewPage({
    required this.imageUrl,
    this.title,
  });

  final String imageUrl;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title ?? 'Photo', maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stack) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not load image.',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
