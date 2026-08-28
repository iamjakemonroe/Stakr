import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:stakr/features/auth/presentation/providers/auth_providers.dart';
import 'package:stakr/features/coins/data/coin_repository.dart';
import 'package:stakr/features/coins/presentation/providers/coin_balance_provider.dart';

final _fakeUser = User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: DateTime(2026).toIso8601String(),
);

class _FakeCoinRepository implements CoinRepository {
  _FakeCoinRepository(this._values);

  final List<int> _values;

  @override
  Stream<int> watchBalance(String userId) => Stream.fromIterable(_values);
}

void main() {
  test('coinBalanceProvider emits Stream.empty when signed out', () async {
    final container = ProviderContainer(
      overrides: [currentUserProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);

    final sub = container.listen(coinBalanceProvider, (_, _) {});
    // No user -> underlying stream never emits; provider stays in loading.
    expect(sub.read(), const AsyncValue<int>.loading());
  });

  test('coinBalanceProvider propagates values from the repository stream', () async {
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(_fakeUser),
        coinRepositoryProvider.overrideWithValue(
          _FakeCoinRepository([1000, 1450]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final emissions = <AsyncValue<int>>[];
    container.listen(coinBalanceProvider, (_, next) => emissions.add(next), fireImmediately: true);

    await Future<void>.delayed(Duration.zero);

    expect(emissions.last.value, 1450);
  });
}
