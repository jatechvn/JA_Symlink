import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/app_config.dart';
import 'package:ja_symlink/theme/theme_provider.dart';

void main() {
  test('restores saved glass values and clamps invalid ranges', () async {
    await AppConfig.set('card_blur', '999');
    await AppConfig.set('card_opacity', '-1');
    await AppConfig.set('dialog_blur', 'not-a-number');
    await AppConfig.set('dialog_opacity', '2');
    await AppConfig.set('dropdown_blur', 'NaN');
    await AppConfig.set('dropdown_opacity', '0');

    final theme = ThemeProvider(initialMode: 'dark');

    expect(theme.cardBlur, 40.0);
    expect(theme.cardOpacity, 0.05);
    expect(theme.dialogBlur, inInclusiveRange(0.0, 40.0));
    expect(theme.dialogOpacity, 1.0);
    expect(theme.dropdownBlur, inInclusiveRange(0.0, 40.0));
    expect(theme.dropdownOpacity, 0.1);

    theme.setLiveGlassmorphism(
      cardBlur: -10,
      cardOpacity: double.infinity,
      dialogBlur: 100,
      dialogOpacity: double.nan,
    );

    expect(theme.cardBlur, 0.0);
    expect(theme.cardOpacity, 0.05);
    expect(theme.dialogBlur, 40.0);
    expect(theme.dialogOpacity, 0.1);
  });
}
