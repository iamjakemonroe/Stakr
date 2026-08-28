import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stakr/features/auth/presentation/providers/auth_providers.dart';
import 'package:stakr/features/coins/presentation/providers/coin_balance_provider.dart';
import 'package:stakr/features/home/presentation/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen renders the live coin balance, not a hardcoded value', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coinBalanceProvider.overrideWith((ref) => Stream.value(1000)),
          isAnonymousProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('1000'), findsOneWidget);
    // Anonymous-only "save your account" banner should not show.
    expect(find.textContaining('Save your account'), findsNothing);
  });

  testWidgets('HomeScreen shows the save-account banner for anonymous users', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coinBalanceProvider.overrideWith((ref) => Stream.value(1000)),
          isAnonymousProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Save your account'), findsOneWidget);
  });
}
