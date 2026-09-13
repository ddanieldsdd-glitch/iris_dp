import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_navigation_scope.dart';
import 'package:iris_dp/features/visual_bible/widgets/narrative_deck/narrative_card_detail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('open usa el navigator anidado del scope, no el raíz', (
    tester,
  ) async {
    var openedId = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: BibleNavigationScope(
          openMoodboard: ({sectionId, moodboardFilter}) {},
          openLocations: ({siteId, setId}) {},
          openNarrativeCardDetail: ({
            required int cardId,
            Widget? technicalPanel,
            VoidCallback? onOpenLocation,
          }) async {
            openedId = cardId;
          },
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => NarrativeCardDetailPage.open(
                context,
                projectId: 1,
                bibleId: 1,
                cardId: 42,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(openedId, 42);
    expect(find.byType(NarrativeCardDetailPage), findsNothing);
  });
}
