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

  /// 공항 코드에서 국가 코드 추론
  static String? getCountryCodeFromAirport(String airportCode) {
    final code = airportCode.toUpperCase();
    
    // 공항 코드 -> 국가 코드 매핑
    final airportToCountry = {
      // 일본
      'NRT': 'JP', 'HND': 'JP', 'KIX': 'JP', 'FUK': 'JP', 'CTS': 'JP',
      'NGO': 'JP', 'OKA': 'JP', 'KMQ': 'JP', 'SDJ': 'JP',
      // 중국
      'PVG': 'CN', 'PEK': 'CN', 'PKX': 'CN', 'CAN': 'CN', 'SZX': 'CN',
      'NGB': 'CN', 'NKG': 'CN', 'YNJ': 'CN',
      // 태국
      'BKK': 'TH', 'DMK': 'TH', 'HKT': 'TH', 'CNX': 'TH',
      // 베트남
      'HAN': 'VN', 'SGN': 'VN', 'DAD': 'VN', 'PQC': 'VN',
      // 필리핀
      'MNL': 'PH', 'CEB': 'PH', 'KLO': 'PH', 'DVO': 'PH',
      // 싱가포르
      'SIN': 'SG',
      // 말레이시아
      'KUL': 'MY', 'PEN': 'MY', 'BKI': 'MY',
      // 인도네시아
      'CGK': 'ID', 'DPS': 'ID', 'BTH': 'ID',
      // 호주
      'SYD': 'AU', 'MEL': 'AU', 'BNE': 'AU', 'PER': 'AU',
      // 미국
      'JFK': 'US', 'LAX': 'US', 'SFO': 'US', 'HNL': 'US',
      // 영국
      'LHR': 'GB', 'LGW': 'GB',
      // 프랑스
      'CDG': 'FR', 'ORY': 'FR',
      // 이탈리아
      'FCO': 'IT', 'MXP': 'IT',
      // 스페인
      'MAD': 'ES', 'BCN': 'ES',
      // 대만
      'TPE': 'TW', 'KHH': 'TW',
      // 홍콩
      'HKG': 'HK',
      // 캄보디아
      'PNH': 'KH', 'REP': 'KH',
      // 라오스
      'VTE': 'LA', 'LPQ': 'LA',
      // 미얀마
      'RGN': 'MM', 'NYT': 'MM',
    };
    
    return airportToCountry[code];
  }

  /// 도시명에서 국가 코드 추론
  static String? getCountryCodeFromCity(String cityName) {
    final city = cityName.toLowerCase();
    
    // 도시명 -> 국가 코드 매핑
    final cityToCountry = {
      // 일본
      '도쿄': 'JP', 'tokyo': 'JP', '나리타': 'JP', 'narita': 'JP',
      '오사카': 'JP', 'osaka': 'JP', '후쿠오카': 'JP', 'fukuoka': 'JP',
      '삿포로': 'JP', 'sapporo': 'JP', '센다이': 'JP', 'sendai': 'JP',
      '나고야': 'JP', 'nagoya': 'JP', '오키나와': 'JP', 'okinawa': 'JP',
      // 중국
      '상하이': 'CN', 'shanghai': 'CN', '베이징': 'CN', 'beijing': 'CN',
      '광저우': 'CN', 'guangzhou': 'CN', '심천': 'CN', 'shenzhen': 'CN',
      '난징': 'CN', 'nanjing': 'CN', '연지': 'CN', 'yanji': 'CN',
      // 태국
      '방콕': 'TH', 'bangkok': 'TH', '푸켓': 'TH', 'phuket': 'TH',
      '치앙마이': 'TH', 'chiangmai': 'TH',
      // 베트남
      '하노이': 'VN', 'hanoi': 'VN', '호치민': 'VN', 'hochiminh': 'VN',
      '다낭': 'VN', 'danang': 'VN', '푸꾸옥': 'VN', 'phuquoc': 'VN',
      // 필리핀
      '마닐라': 'PH', 'manila': 'PH', '세부': 'PH', 'cebu': 'PH',
      '보라카이': 'PH', 'boracay': 'PH', '다바오': 'PH', 'davao': 'PH',
      // 싱가포르
      '싱가포르': 'SG', 'singapore': 'SG',
      // 말레이시아
      '쿠알라룸푸르': 'MY', 'kualalumpur': 'MY', '페낭': 'MY', 'penang': 'MY',
      '코타키나발루': 'MY', 'kotakinabalu': 'MY',
      // 인도네시아
      '자카르타': 'ID', 'jakarta': 'ID', '발리': 'ID', 'bali': 'ID',
      '바탐': 'ID', 'batam': 'ID',
      // 호주
      '시드니': 'AU', 'sydney': 'AU', '멜버른': 'AU', 'melbourne': 'AU',
      // 미국
      '뉴욕': 'US', 'newyork': 'US', '로스앤젤레스': 'US', 'losangeles': 'US',
      '하와이': 'US', 'hawaii': 'US',
      // 대만
      '타이베이': 'TW', 'taipei': 'TW', '가오슝': 'TW', 'kaohsiung': 'TW',
      // 홍콩
      '홍콩': 'HK', 'hongkong': 'HK',
    };
    
    // 정확한 매칭 시도
    if (cityToCountry.containsKey(city)) {
      return cityToCountry[city];
    }
    
    // 부분 매칭 시도 (예: "도쿄(나리타)" -> "도쿄" 포함)
    for (var entry in cityToCountry.entries) {
      if (city.contains(entry.key) || entry.key.contains(city)) {
        return entry.value;
      }
    }
    
    return null;
  }

  /// 국가 코드 추론 (공항 코드 우선, 없으면 도시명, 없으면 기본값)
  static String inferCountryCode({
    String? countryCode,
    String? airportCode,
    String? cityName,
  }) {
    // 1. countryCode가 있으면 사용
    if (countryCode != null && countryCode.isNotEmpty) {
      return countryCode.toUpperCase();
    }
    
    // 2. 공항 코드에서 추론
    if (airportCode != null && airportCode.isNotEmpty) {
      final code = getCountryCodeFromAirport(airportCode);
      if (code != null) return code;
    }
    
    // 3. 도시명에서 추론
    if (cityName != null && cityName.isNotEmpty) {
      final code = getCountryCodeFromCity(cityName);
      if (code != null) return code;
    }
    
    // 4. 기본값 (한국)
    return 'KR';
  }

  /// 국가 코드에서 국가명 가져오기
  static String getCountryName(String countryCode) {
    final code = countryCode.toUpperCase();
    final countryNames = {
      'KR': '한국',
      'JP': '일본',
      'CN': '중국',
      'TH': '태국',
      'VN': '베트남',
      'PH': '필리핀',
      'SG': '싱가포르',
      'MY': '말레이시아',
      'ID': '인도네시아',
      'AU': '호주',
      'US': '미국',
      'GB': '영국',
      'FR': '프랑스',
      'DE': '독일',
      'IT': '이탈리아',
      'ES': '스페인',
      'PT': '포르투갈',
      'GR': '그리스',
      'TR': '터키',
      'AE': 'UAE',
      'IN': '인도',
      'TW': '대만',
      'HK': '홍콩',
      'MM': '미얀마',
      'KH': '캄보디아',
      'LA': '라오스',
    };
    return countryNames[code] ?? countryCode;
  }
}

