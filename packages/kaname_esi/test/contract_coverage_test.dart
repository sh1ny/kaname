import 'package:test/test.dart';

import 'support/contracts.dart';
import 'support/exchanges.dart';

void main() {
  final names = Exchange.all();
  final exchanges = [for (final name in names) Exchange.load(name)];

  test('every listed inbound and outbound construct has an asserting '
      'exchange', () {
    final covered = {
      for (final exchange in exchanges)
        if (contracts.containsKey(exchange.name)) ...exchange.constructs,
    };
    expect(
      [
        for (final construct in requiredConstructs)
          if (!covered.contains(construct)) construct,
      ],
      isEmpty,
      reason: 'constructs without an asserting exchange',
    );
  });

  test('every exchange file has a contract and every contract a file', () {
    expect(names.toSet(), contracts.keys.toSet());
  });

  test('each set holds at least one exchange', () {
    for (final set in exchangeSets) {
      expect(
        names.where((n) => n.startsWith('$set/')),
        isNotEmpty,
        reason: set,
      );
    }
  });

  test('exchanges tag only listed constructs', () {
    for (final exchange in exchanges) {
      expect(
        requiredConstructs.toSet().containsAll(exchange.constructs),
        isTrue,
        reason: '${exchange.name}: ${exchange.constructs}',
      );
    }
  });
}
