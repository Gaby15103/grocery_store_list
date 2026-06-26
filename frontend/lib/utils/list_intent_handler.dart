import 'dart:async';
import 'package:app_links/app_links.dart';

class ListIntentHandler {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  void initIncomingLinks(Function(String) onIncomingItem) {
    // app_links automatically catches both cold starts and warm background resumes!
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      _parseAndAdd(uri, onIncomingItem);
    }, onError: (err) {
      print("❌ AppLinks Stream Error: $err");
    });
  }

  void _parseAndAdd(Uri uri, Function(String) onIncomingItem) {
    final itemName = uri.queryParameters['itemName'];
    if (itemName != null && itemName.isNotEmpty) {
      onIncomingItem(itemName);
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
