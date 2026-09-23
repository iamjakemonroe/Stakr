import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts any [Stream] into a [Listenable] so go_router's `refreshListenable`
/// re-evaluates `redirect` whenever the stream emits (e.g. on every auth
/// state change), without go_router needing to know about Riverpod/Supabase.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
