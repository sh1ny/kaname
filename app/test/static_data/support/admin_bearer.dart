import 'package:flutter_riverpod/flutter_riverpod.dart';

final testBearerProvider = NotifierProvider<TestBearer, String?>(
  TestBearer.new,
);

final class TestBearer extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}
