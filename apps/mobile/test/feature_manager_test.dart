import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/feature_manager.dart';
import 'package:tarteel/src/remote_config.dart';
import 'package:tarteel/src/repository.dart';

void main() {
  test('semantic versions compare numerically', () {
    expect(
      SemanticVersion.parse('0.10.0').compareTo(SemanticVersion.parse('0.9.9')),
      greaterThan(0),
    );
    expect(
      SemanticVersion.parse('1.2').compareTo(SemanticVersion.parse('1.2.0')),
      0,
    );
    expect(() => SemanticVersion.parse('1.bad.0'), throwsFormatException);
  });

  test('feature gates and update policy use one central source', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'tarteel_remote_config:v1':
          '{"radio_enabled":false,"prayer_features_enabled":true,'
          '"adhkar_enabled":false,"offline_downloads_enabled":true,'
          '"minimum_android_version":"0.5.0",'
          '"recommended_android_version":"0.6.0",'
          '"latest_android_version":"0.7.0"}',
    });
    final config = TarteelRemoteConfig(
      _Repository(),
      await SharedPreferences.getInstance(),
    )..load();
    final features = FeatureManager(config: config, installedVersion: '0.5.3');
    expect(features.enabled(TarteelFeature.radio), isFalse);
    expect(features.routeAllowed('/radio'), isFalse);
    expect(features.routeAllowed('/prayer-times'), isTrue);
    expect(features.routeAllowed('/adhkar'), isFalse);
    expect(features.updateRequirement, UpdateRequirement.recommended);
  });
}

class _Repository implements TarteelRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
