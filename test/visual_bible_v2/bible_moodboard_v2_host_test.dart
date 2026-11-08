import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/bible_block_catalog.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_block.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_document.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_page.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_page_mode.dart';
import 'package:iris_dp/features/visual_bible/v2/renderer/bible_moodboard_v2_host.dart';
import 'package:iris_dp/features/visual_bible/v2/renderer/bible_page_renderer.dart';
import 'package:iris_dp/features/visual_bible/widgets/moodboard_section.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

void main() {
  testWidgets('página moodboard monta MoodboardSection en V2', (tester) async {
    const projectId = 7;
    const bibleId = 3;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final built = BiblePageRenderer(
              page: const BiblePage(
                id: BibleMoodboardV2Host.pageId,
                groupId: 'operational',
                label: 'Moodboard',
                legacySectionId: BibleSectionId.moodboard,
                pageMode: BiblePageMode.recipe,
              ),
              document: BibleDocument(
                projectId: projectId,
                bibleId: bibleId,
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
              projectId: projectId,
              bibleId: bibleId,
              sectionBuilder: BibleMoodboardV2Host.wrap(
                projectId: projectId,
                bibleId: bibleId,
              ),
            ).build(context);

            expect(built, isA<MoodboardSection>());
            final section = built as MoodboardSection;
            expect(section.projectId, projectId);
            expect(section.bibleId, bibleId);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
  });

  testWidgets('moodboardRefs en otras páginas no usa el host moodboard', (
    tester,
  ) async {
    var hostInvoked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BiblePageRenderer(
            page: const BiblePage(
              id: 'concept',
              groupId: 'narrative',
              label: 'Concepto',
              pageMode: BiblePageMode.recipe,
              blocks: [
                const BibleBlock(
                  id: 'concept__refs',
                  type: BibleBlockKind.moodboardRefs,
                  content: {
                    'subsectionKind': 'moodboardRefs',
                    'images': <Map<String, dynamic>>[],
                  },
                ),
              ],
            ),
            document: BibleDocument(
              projectId: 1,
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
            projectId: 1,
            sectionBuilder: (_) {
              hostInvoked = true;
              return const Text('HOST');
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(hostInvoked, isFalse);
    expect(find.byType(MoodboardSection), findsNothing);
    expect(find.textContaining('Sin referencias'), findsOneWidget);
  });
}
