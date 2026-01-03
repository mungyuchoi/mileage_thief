import 'package:flutter/material.dart';

class DealImageUtils {
  /// 항공사 로고 이미지 경로
  static String getAirlineLogoPath(String airlineCode) {
    return 'asset/img/airline_${airlineCode.toLowerCase()}.png';
  }

  /// 여행사 로고 이미지 경로
  static String getAgencyLogoPath(String agencyCode) {
    return 'asset/img/agency_${agencyCode.toLowerCase()}.png';
  }

  /// 국가 국기 이미지 경로
  static String getCountryFlagPath(String countryCode) {
    return 'asset/img/flag_${countryCode.toLowerCase()}.png';
  }

  /// 항공사 로고 이미지 위젯
  static Widget getAirlineLogo(String airlineCode, {double? width, double? height}) {
    return Image.asset(
      getAirlineLogoPath(airlineCode),
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width ?? 40,
          height: height ?? 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.flight, size: (width ?? 40) * 0.6, color: Colors.grey[600]),
        );
      },
    );
  }

  /// 여행사 로고 이미지 위젯
  static Widget getAgencyLogo(String agencyCode, {double? width, double? height}) {
    return Image.asset(
      getAgencyLogoPath(agencyCode),
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width ?? 40,
          height: height ?? 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.business, size: (width ?? 40) * 0.6, color: Colors.grey[600]),
        );
      },
    );
  }

  /// 국가 국기 이미지 위젯
  static Widget getCountryFlag(String countryCode, {double? width, double? height}) {
    return ClipOval(
      child: Image.asset(
        getCountryFlagPath(countryCode),
        width: width ?? 24,
        height: height ?? 24,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width ?? 24,
            height: height ?? 24,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.flag, size: (width ?? 24) * 0.6, color: Colors.grey[600]),
          );
        },
      ),
    );
  }

  /// 항공사 코드 목록 (이미지 파일명 생성용)
  static List<String> getAirlineCodes() {
    return [
      // 한국 항공사
      '7C', // 제주항공
      'KE', // 대한항공
      'OZ', // 아시아나항공
      'LJ', // 진에어
      'TW', // 티웨이항공
      'BX', // 에어부산
      'ZE', // 이스타항공
      'RS', // 에어서울
      'YP', // 에어프레미아
      'RF', // 에어로케이항공
      // 일본 항공사
      'NH', // 전일본공수 (ANA)
      'JL', // 일본항공 (JAL)
      'MM', // 피치항공
      'GK', // 제트스타재팬
      'SL', // 타이라이항공
      // 동남아시아 항공사
      '5J', // 세부퍼시픽항공
      'PR', // 필리핀항공
      'AK', // 에어아시아
      'D7', // 에어아시아X
      'OD', // 바틱에어 말레이시아
      'JQ', // 젯스타항공
      'VN', // 베트남항공
      'VJ', // 비엣젯항공
      'VZ', // 타이 비엣젯항공
      'TR', // 스쿠트항공
      'WE', // 파라타항공
      // 동아시아 항공사
      'CX', // 캐세이퍼시픽
      'HX', // 홍콩항공
      'CI', // 중화항공
      // 기타
      'BI', // 로열브루나이항공
    ];
  }

  /// 여행사 코드 목록 (이미지 파일명 생성용)
  static List<String> getAgencyCodes() {
    return [
      'hanatour',    // 하나투어
      'modetour',    // 모두투어
      'ttangdeal',   // 땡처리닷컴
      'yellowtour',  // 노랑풍선
      'onlinetour',  // 온라인투어
    ];
  }

  /// 국가 코드 목록 (이미지 파일명 생성용)
  static List<String> getCountryCodes() {
    return [
      'KR', // 한국
      'JP', // 일본
      'CN', // 중국
      'TH', // 태국
      'VN', // 베트남
      'PH', // 필리핀
      'SG', // 싱가포르
      'MY', // 말레이시아
      'ID', // 인도네시아
      'AU', // 호주
      'US', // 미국
      'GB', // 영국
      'FR', // 프랑스
      'DE', // 독일
      'IT', // 이탈리아
      'ES', // 스페인
      'PT', // 포르투갈
      'GR', // 그리스
      'TR', // 터키
      'AE', // UAE
      'IN', // 인도
      'TW', // 대만
      'HK', // 홍콩
      'MM', // 미얀마
      'KH', // 캄보디아
      'LA', // 라오스
    ];
  }
}

