import 'package:test/test.dart';

import 'support/contracts.dart';
import 'support/exchanges.dart';

void main() {
  final names = Exchange.all();
  final exchanges = [for (final name in names) Exchange.load(name)];

  test('every listed inbound and outbound construct has an exchange whose '
      'contract asserts it', () async {
    final covered = <String>{};
    for (final exchange in exchanges) {
      final contract = contracts[exchange.name];
      if (contract == null) continue;
      final asserted = {
        for (final (what, _, _) in await contract(exchange)) what,
      };
      for (final construct in exchange.constructs) {
        if (asserted.contains(requiredConstructs[construct])) {
          covered.add(construct);
        }
      }
    }
    expect(
      [
        for (final construct in requiredConstructs.keys)
          if (!covered.contains(construct)) construct,
      ],
      isEmpty,
      reason: 'constructs without an exchange asserting them',
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
        requiredConstructs.keys.toSet().containsAll(exchange.constructs),
        isTrue,
        reason: '${exchange.name}: ${exchange.constructs}',
      );
    }
  });
}
