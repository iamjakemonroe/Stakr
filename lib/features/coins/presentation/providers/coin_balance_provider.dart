import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/coin_repository.dart';

final coinRepositoryProvider = Provider<CoinRepository>((ref) {
  return CoinRepository(ref.watch(supabaseClientProvider));
});

/// Live coin balance for the signed-in user. Watches [currentUserProvider] so
/// it automatically re-subscribes on sign-in and tears down on sign-out
/// without any manual stream management.
final coinBalanceProvider = StreamProvider<int>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const Stream.empty();
  }
  return ref.watch(coinRepositoryProvider).watchBalance(user.id);
});
