import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synclip/shared/widgets/device_ring.dart';

const _self = RingNode(
  name: 'this phone',
  icon: Icons.smartphone,
  color: Colors.orange,
);
const _mac = RingNode(name: 'MacBook', icon: Icons.laptop, color: Colors.blue);
const _pc = RingNode(
  name: 'Windows PC',
  icon: Icons.desktop_windows,
  color: Colors.green,
);
const _lab = RingNode(
  name: 'Lab PC',
  icon: Icons.language,
  color: Colors.purple,
  online: false,
);

void main() {
  group('DeviceRing.describe', () {
    test('lists online devices then offline ones', () {
      expect(
        DeviceRing.describe(_self, const [_mac, _pc, _lab]),
        '3 devices online: MacBook, Windows PC, this phone. Lab PC offline.',
      );
    });

    test('alone in the room', () {
      expect(
        DeviceRing.describe(_self, const []),
        '1 device online: this phone.',
      );
    });
  });

  testWidgets('exposes the description as one semantics label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: DeviceRing(self: _self, others: [_mac, _lab]),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        '2 devices online: MacBook, this phone. Lab PC offline.',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
