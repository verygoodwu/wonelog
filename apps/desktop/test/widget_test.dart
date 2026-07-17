import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wonelog_client/main.dart';
import 'package:wonelog_client/models/summaries.dart';

void main() {
  testWidgets('renders dashboard page content', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardPage(
            loading: false,
            config: const <String, dynamic>{
              'nickname': 'Your Name',
              'greeting': 'Hello'
            },
            cities: const <dynamic>[],
            links: const <dynamic>[],
            projects: const <dynamic>[],
            articles: const <ArticleSummary>[],
            versions: const <VersionSummary>[],
            publishStep: 'idle',
            statusText: 'Wonelog Core connected',
            publishing: false,
            onRefresh: () {},
            onPublish: (_) async {},
            onSync: () {},
            onCreateVersion: () {},
            onNavigate: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Wonelog 管理台'), findsOneWidget);
    expect(find.text('发布控制'), findsOneWidget);
  });
}
