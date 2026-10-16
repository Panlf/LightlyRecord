import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lightly_record/theme/app_theme.dart';
import 'package:lightly_record/widgets/num_keypad.dart';

void main() {
  testWidgets('键盘在页面 Column 中可正常布局（无无界高度断言）', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildThemeData(AppThemeId.mint),
        home: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const Expanded(child: SizedBox()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: NumKeypad(
                    onDigit: (_) {},
                    onBackspace: () {},
                    onDone: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    debugPrint('KEYPAD exception: ${tester.takeException()}');
    expect(tester.takeException(), isNull);
    for (final t in ['1', '4', '7', '00', '完成']) {
      expect(find.text(t), findsOneWidget, reason: '按键「$t」应渲染');
    }
  });
}
