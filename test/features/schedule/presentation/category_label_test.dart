import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/schedule/presentation/widgets/category_label.dart';

void main() {
  group('shortenCategory', () {
    test('알려진 카테고리는 정해진 짧은 라벨로 매핑', () {
      expect(shortenCategory('일과운영관리'), '일과운영');
      expect(shortenCategory('교육과정계획수립운영'), '교육과정');
      expect(shortenCategory('조직및통계관리'), '조직통계');
      expect(shortenCategory('학생학적관리'), '학생학적');
      expect(shortenCategory('학교행사자율활동'), '학교행사');
      expect(shortenCategory('포상수상대장관리'), '포상수상');
      expect(shortenCategory('학교생활세부사항기록부관리'), '학교생활');
      expect(shortenCategory('학교운영계획수립실적관리'), '학교운영');
      expect(shortenCategory('인사징계위원회구성운영'), '인사징계');
    });

    test('매칭 안 되는 카테고리는 4글자 이내면 그대로', () {
      expect(shortenCategory('기타'), '기타');
      expect(shortenCategory('생활지도'), '생활지도');
    });

    test('매칭 안 되는 5글자 이상 카테고리는 4글자 + 말줄임표', () {
      expect(shortenCategory('알수없는분류명'), '알수없는…');
    });

    test('빈 문자열은 빈 문자열', () {
      expect(shortenCategory(''), '');
    });
  });

  group('categoryColor', () {
    test('주요 4개 카테고리는 전용 색상', () {
      expect(categoryColor('일과운영관리'), AppColors.categoryDailyOps);
      expect(categoryColor('교육과정계획수립운영'), AppColors.categoryCurriculum);
      expect(categoryColor('조직및통계관리'), AppColors.categoryOrganization);
      expect(categoryColor('학생학적관리'), AppColors.categoryStudentRecord);
    });

    test('그 외 카테고리는 기본 색상', () {
      expect(categoryColor('학교행사자율활동'), AppColors.categoryDefault);
      expect(categoryColor(''), AppColors.categoryDefault);
    });
  });
}
