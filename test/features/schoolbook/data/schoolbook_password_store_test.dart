import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/schoolbook/data/schoolbook_password_store.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('저장한 비밀번호를 되읽는다', () async {
    const store = SchoolbookPasswordStore();
    expect(await store.read(), isNull);
    await store.write('1234');
    expect(await store.read(), '1234');
  });

  test('보안 저장소의 키는 schoolbook_password_v1', () async {
    await const SchoolbookPasswordStore().write('1234');
    expect(await const FlutterSecureStorage().read(key: 'schoolbook_password_v1'), '1234');
  });

  test('숫자 4자리가 아니면 저장하지 않는다', () async {
    const store = SchoolbookPasswordStore();
    await store.write('12a4');
    await store.write('123');
    expect(await store.read(), isNull);
  });

  test('지우면 null', () async {
    const store = SchoolbookPasswordStore();
    await store.write('1234');
    await store.delete();
    expect(await store.read(), isNull);
  });
}
