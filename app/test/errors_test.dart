import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:nawahflex_app/core/error_reporter.dart';
import 'package:nawahflex_app/core/errors.dart';

void main() {
  group('expectRows — الكتابة التي رفضتها RLS بصمت', () {
    test('قائمة فارغة (لم يُصب أي صف) → WriteDenied', () {
      expect(() => expectRows(<dynamic>[]), throwsA(isA<WriteDenied>()));
    });
    test('null → WriteDenied', () {
      expect(() => expectRows(null), throwsA(isA<WriteDenied>()));
    });
    test('صف واحد → يمرّ', () {
      expect(() => expectRows([{'id': 'x'}]), returnsNormally);
    });
  });

  group('userMessageFor — عربية دائماً، لا نص استثناء خام', () {
    final cases = <Object>[
      const WriteDenied(),
      TimeoutException('t'),
      const PostgrestException(message: 'denied', code: '42501'),
      const PostgrestException(message: 'dup', code: '23505'),
      const PostgrestException(message: 'fk', code: '23503'),
      const PostgrestException(message: '?', code: 'XX000'),
      Exception('ClientException: Failed to fetch'),
      StateError('غريب'),
    ];
    for (final e in cases) {
      test('$e', () {
        final m = userMessageFor(e);
        expect(m, isNotEmpty);
        expect(RegExp(r'[A-Za-z]').hasMatch(m), isFalse, reason: m);
      });
    }
    test('الصلاحية والتكرار لهما رسالتان مختلفتان', () {
      expect(
        userMessageFor(const PostgrestException(message: '', code: '42501')),
        isNot(userMessageFor(const PostgrestException(message: '', code: '23505'))),
      );
    });
  });

  group('ErrorReporter', () {
    late List<Map<String, dynamic>> sent;
    String? user;
    ErrorReporter make({int max = 20}) => ErrorReporter(
          send: (row) async => sent.add(row),
          currentUserId: () => user,
          maxPerSession: max,
        );

    setUp(() {
      sent = [];
      user = 'u1';
    });

    test('يرسل مرة واحدة لكل رسالة في الجلسة', () {
      final r = make();
      r.report(StateError('a'));
      r.report(StateError('a'));
      r.report(StateError('b'));
      expect(sent.length, 2);
      expect(sent.first['profile_id'], 'u1');
    });

    test('يتوقّف عند الحدّ الأقصى', () {
      final r = make(max: 3);
      for (var i = 0; i < 10; i++) {
        r.report(StateError('e$i'));
      }
      expect(sent.length, 3);
    });

    test('لا يرسل قبل تسجيل الدخول', () {
      user = null;
      make().report(StateError('x'));
      expect(sent, isEmpty);
    });

    test('WriteDenied جواب صلاحية لا خلل — لا يُرسل', () {
      make().report(const WriteDenied());
      expect(sent, isEmpty);
    });

    test('يقصّ الرسائل الطويلة ضمن حدود الجدول', () {
      make().report(StateError('x' * 2000), StackTrace.fromString('s' * 9000));
      expect((sent.single['message'] as String).length, lessThanOrEqualTo(500));
      expect((sent.single['stack'] as String).length, lessThanOrEqualTo(4000));
    });
  });
}
