import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/widgets/status_banner.dart';

void main() {
  testWidgets('renders reusable status banner', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBanner(
            icon: Icons.cloud_off_rounded,
            text: 'Coleta salva offline',
            tone: BannerTone.info,
          ),
        ),
      ),
    );

    expect(find.text('Coleta salva offline'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
  });
}
