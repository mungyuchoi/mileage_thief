import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_thief/utils/url_classification.dart';

void main() {
  group('UrlClassification.isDirectImageUrl', () {
    test('does not classify product links with image query params as images',
        () {
      const url =
          'https://mobile.lpoint.com/app/common/AMZZ300400.do?type=giftiel'
          '&pdSeq=00GL010R00305'
          '&mobLstImgPhNm=https://image.multicon.co.kr/GL010R/0002.jpg'
          '&evnNm=gift-card';

      expect(UrlClassification.isDirectImageUrl(url), isFalse);
    });

    test('classifies direct image paths as images', () {
      expect(
        UrlClassification.isDirectImageUrl(
          'https://image.multicon.co.kr/GL010R/0002.jpg?size=large',
        ),
        isTrue,
      );
    });

    test('classifies Firebase Storage media URLs as images', () {
      expect(
        UrlClassification.isDirectImageUrl(
          'https://firebasestorage.googleapis.com/v0/b/app/o/posts%2Fimage'
          '?alt=media&token=abc',
        ),
        isTrue,
      );
    });
  });
}
