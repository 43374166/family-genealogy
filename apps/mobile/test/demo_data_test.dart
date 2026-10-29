import 'package:family_tree/data/demo_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('demo family relationships', () {
    test('spouse links are symmetric', () {
      for (final member in DemoData.treeMembers) {
        final spouse = DemoData.spouseOf(member.id);
        if (spouse == null) continue;
        expect(
          DemoData.spouseOf(spouse.id)?.id,
          member.id,
          reason: '${member.name} and ${spouse.name} must point to each other',
        );
      }
    });

    test('ancestor branch has the expected generations', () {
      final zhangYi = DemoData.zhangYi;
      expect(zhangYi.generation, 8);
      expect(DemoData.fatherOf(zhangYi.id)?.name, '张宏远');
      expect(DemoData.motherOf(zhangYi.id)?.name, '苏氏');
      expect(DemoData.spouseOf(zhangYi.id)?.name, '余梦');
      expect(DemoData.childrenOf(zhangYi.id), hasLength(5));
    });

    test('sixth-generation matriarch resolves to the right family', () {
      final linShi = DemoData.linShi;
      expect(DemoData.spouseOf(linShi.id)?.name, '张天明');
      expect(DemoData.childrenOf(linShi.id).map((member) => member.name), [
        '张宏远',
      ]);
      expect(DemoData.fatherOf(linShi.id), isNull);
    });

    test('current account is not accidentally linked into the tree', () {
      expect(DemoData.currentUser.isCurrentUser, isTrue);
      expect(DemoData.spouseOf(DemoData.currentUser.id), isNull);
      expect(DemoData.childrenOf(DemoData.currentUser.id), isEmpty);
    });
  });
}
