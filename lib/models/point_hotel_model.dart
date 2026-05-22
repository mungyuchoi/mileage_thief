class PointHotelAmenity {
  final String title;
  final String subtitle;
  final bool included;

  const PointHotelAmenity({
    required this.title,
    this.subtitle = '',
    this.included = true,
  });
}

class PointHotelInfoItem {
  final String title;
  final String body;

  const PointHotelInfoItem({
    required this.title,
    required this.body,
  });
}

class PointHotelInfoSection {
  final String title;
  final List<PointHotelInfoItem> items;

  const PointHotelInfoSection({
    required this.title,
    required this.items,
  });
}

class PointHotelCalendarEntry {
  final String date;
  final int points;
  final int? cashKrw;

  const PointHotelCalendarEntry({
    required this.date,
    required this.points,
    this.cashKrw,
  });
}

class PointHotel {
  final String id;
  final String name;
  final String city;
  final String country;
  final String address;
  final String brand;
  final String imageUrl;
  final List<String> galleryUrls;
  final double rating;
  final int pointsPerNight;
  final int cashPerNightKrw;
  final bool guestFavorite;
  final String description;
  final List<String> amenities;
  final List<int> calendarPoints;
  final String loyaltyProgram;
  final String propertyCode;
  final String officialUrl;
  final String phone;
  final String checkInTime;
  final String checkOutTime;
  final int? reviewCount;
  final String mapUrl;
  final double? latitude;
  final double? longitude;
  final String pointCalendarNote;
  final List<PointHotelAmenity> amenityDetails;
  final List<PointHotelInfoSection> detailSections;
  final List<PointHotelCalendarEntry> calendarEntries;

  const PointHotel({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    required this.address,
    required this.brand,
    required this.imageUrl,
    required this.galleryUrls,
    required this.rating,
    required this.pointsPerNight,
    required this.cashPerNightKrw,
    required this.guestFavorite,
    required this.description,
    required this.amenities,
    required this.calendarPoints,
    this.loyaltyProgram = '',
    this.propertyCode = '',
    this.officialUrl = '',
    this.phone = '',
    this.checkInTime = '',
    this.checkOutTime = '',
    this.reviewCount,
    this.mapUrl = '',
    this.latitude,
    this.longitude,
    this.pointCalendarNote = '',
    this.amenityDetails = const [],
    this.detailSections = const [],
    this.calendarEntries = const [],
  });

  String get locationText => '$city, $country';

  String get hostText => '$brand이(가) 호스팅';

  String get programText => loyaltyProgram.isEmpty ? brand : loyaltyProgram;

  bool get isMarriottBonvoy {
    final haystack = [
      loyaltyProgram,
      officialUrl,
      propertyCode,
    ].join(' ').toLowerCase();
    return haystack.contains('marriott') ||
        officialUrl.contains('marriott.com');
  }

  double get krwPerPoint => cashPerNightKrw / pointsPerNight;

  int awardPointsForNights(int nights) {
    if (nights <= 0) return 0;
    if ((isMarriottBonvoy || brand.toLowerCase().contains('hilton')) &&
        nights >= 5) {
      return pointsPerNight * (nights - (nights ~/ 5));
    }
    return pointsPerNight * nights;
  }

  List<PointHotelAmenity> get displayAmenities {
    if (amenityDetails.isNotEmpty) return amenityDetails;
    return amenities
        .map((title) => PointHotelAmenity(title: title))
        .toList(growable: false);
  }

  String get searchableText {
    return [
      name,
      city,
      country,
      address,
      brand,
      loyaltyProgram,
      propertyCode,
    ].join(' ').toLowerCase();
  }
}

const List<PointHotel> pointHotelSamples = <PointHotel>[
  PointHotel(
    id: 'hyatt_arnjs',
    name: 'Story Hotel Signalfabriken, part of JdV by Hyatt',
    city: 'Stockholm',
    country: 'Sweden',
    address: 'Sundbybergs torg 1, 172 67 Stockholm, Sweden',
    brand: 'Jdv By Hyatt',
    imageUrl: 'https://img.awardtool.com/hotel-imgs/hyatt_arnjs.jpg',
    galleryUrls: [
      'https://img.awardtool.com/hotel-imgs/hyatt_arnjs.jpg',
      'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?auto=format&fit=crop&w=1200&q=80',
    ],
    rating: 4.1,
    pointsPerNight: 3500,
    cashPerNightKrw: 184000,
    guestFavorite: false,
    description:
        '스톡홀름 외곽의 차분한 디자인 호텔입니다. 지하철 접근성이 좋아 짧은 여행에도 포인트 효율을 만들기 좋습니다.',
    amenities: ['무료 Wi-Fi', '피트니스', '레스토랑', '반려동물 가능'],
    calendarPoints: [3500, 3500, 5000, 6500, 3500, 3500, 8000],
  ),
  PointHotel(
    id: 'hilton_dxbjadi',
    name: 'DoubleTree by Hilton Dubai Al Jadaf',
    city: 'Dubai',
    country: 'United Arab Emirates',
    address: 'Al Jadaf, Dubai, United Arab Emirates',
    brand: 'Hilton',
    imageUrl: 'https://img.awardtool.com/hotel-imgs/hilton_dxbjadi.jpg',
    galleryUrls: [
      'https://img.awardtool.com/hotel-imgs/hilton_dxbjadi.jpg',
      'https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1564501049412-61c2a3083791?auto=format&fit=crop&w=1200&q=80',
    ],
    rating: 4.3,
    pointsPerNight: 18000,
    cashPerNightKrw: 242000,
    guestFavorite: true,
    description:
        '두바이 도심과 공항 사이에 위치한 실속형 힐튼 계열 호텔입니다. 현금가가 오르는 시즌에 포인트 사용 후보로 보기 좋습니다.',
    amenities: ['수영장', '무료 주차', '피트니스', '공항 접근'],
    calendarPoints: [18000, 18000, 20000, 24000, 22000, 18000, 19000],
  ),
  PointHotel(
    id: 'ihg_bomap',
    name: 'Holiday Inn Mumbai International Airport',
    city: 'Mumbai',
    country: 'India',
    address: 'Sakinaka Junction, Andheri Kurla Road, Mumbai, India',
    brand: 'Holiday Inn',
    imageUrl: 'https://img.awardtool.com/hotel-imgs/ihg_bomap.jpg',
    galleryUrls: [
      'https://img.awardtool.com/hotel-imgs/ihg_bomap.jpg',
      'https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=1200&q=80',
    ],
    rating: 4.0,
    pointsPerNight: 15000,
    cashPerNightKrw: 168000,
    guestFavorite: true,
    description:
        '뭄바이 국제공항과 가까운 IHG 계열 호텔입니다. 환승이나 늦은 도착 일정에서 포인트 예약의 안정성이 좋습니다.',
    amenities: ['공항 접근', '수영장', '조식', '비즈니스 센터'],
    calendarPoints: [15000, 15000, 16000, 18000, 15000, 20000, 22000],
  ),
  PointHotel(
    id: 'marriott_cjuju',
    name: 'JW 메리어트 제주 리조트 & 스파',
    city: '제주특별자치도 서귀포시',
    country: '대한민국',
    address: '태평로 152, 제주특별자치도 서귀포시, 대한민국 63571',
    brand: 'JW Marriott',
    loyaltyProgram: 'Marriott Bonvoy',
    propertyCode: 'CJUJU',
    officialUrl:
        'https://www.marriott.com/ko/hotels/cjuju-jw-marriott-jeju-resort-and-spa/overview/',
    phone: '+82 64-803-7777',
    checkInTime: '15:00',
    checkOutTime: '11:00',
    reviewCount: 242,
    latitude: 33.24287671066911,
    longitude: 126.5381842623015,
    mapUrl:
        'https://www.google.com/maps/search/?api=1&query=33.24287671066911,126.5381842623015',
    imageUrl:
        'https://cache.marriott.com/is/image/marriotts7prod/jw-cjuju-jw-cjuju-exterior-09453:Wide-Hor?wid=1336&fit=constrain',
    galleryUrls: [
      'https://cache.marriott.com/is/image/marriotts7prod/jw-cjuju-jw-cjuju-exterior-09453:Wide-Hor?wid=1336&fit=constrain',
      'https://cache.marriott.com/is/image/marriotts7prod/jw-cjuju-all-day-dining-24678:Classic-Hor?wid=1140&fit=constrain',
      'https://cache.marriott.com/is/image/marriotts7prod/jw-cjuju-premium-suite-16554:Classic-Hor?wid=1140&fit=constrain',
      'https://cache.marriott.com/is/image/marriotts7prod/jw-cjuju-panorama-suite-33345:Classic-Hor?wid=1140&fit=constrain',
      'https://cache.marriott.com/is/image/marriotts7prod/jw-cjuju-jw-cjuju-king40918-14737:Classic-Hor?wid=1140&fit=constrain',
    ],
    rating: 4.6,
    pointsPerNight: 88000,
    cashPerNightKrw: 820000,
    guestFavorite: true,
    description:
        '제주의 바다를 마주한 JW 메리어트 제주 리조트 & 스파는 제주 국제공항에서 약 50분 거리에 위치합니다. 서귀포 매일올레시장, 산방산, 성산일출봉 등 자연경관과 가까우며, 올데이 다이닝 레스토랑 아일랜드 키친, 더 라운지, 더 플라잉 호그, SPA by JW, 실내외 수영장과 패밀리클럽을 갖춘 럭셔리 리조트입니다. 대부분의 객실에는 오션뷰 발코니가 마련되어 있고 무료 Wi-Fi, 미니바, 대리석 욕조가 제공됩니다.',
    amenities: [
      '레스토랑',
      '스파',
      '피트니스 센터',
      '실내 수영장',
      '야외 수영장',
      '온수 욕조',
      '무료 Wi-Fi',
      '전기차 충전소',
    ],
    amenityDetails: [
      PointHotelAmenity(
          title: '레스토랑', subtitle: 'Island Kitchen, The Flying Hog 등'),
      PointHotelAmenity(title: 'SPA by JW'),
      PointHotelAmenity(title: '피트니스 센터'),
      PointHotelAmenity(title: '실내 수영장'),
      PointHotelAmenity(title: '야외 수영장'),
      PointHotelAmenity(title: '온수 욕조'),
      PointHotelAmenity(title: '무료 Wi-Fi', subtitle: '투숙객 및 Bonvoy 회원'),
      PointHotelAmenity(title: '24시간 룸서비스'),
      PointHotelAmenity(title: '룸 서비스'),
      PointHotelAmenity(title: '턴다운 서비스'),
      PointHotelAmenity(title: '비즈니스 센터'),
      PointHotelAmenity(title: '미팅룸'),
      PointHotelAmenity(title: '자전거 대여'),
      PointHotelAmenity(title: '당일 드라이클리닝'),
      PointHotelAmenity(title: '호텔 내 세탁 시설'),
      PointHotelAmenity(title: '키즈 레크리에이션'),
      PointHotelAmenity(title: '모바일 키'),
      PointHotelAmenity(title: '서비스 요청'),
    ],
    detailSections: [
      PointHotelInfoSection(
        title: '호텔 기본 정보',
        items: [
          PointHotelInfoItem(title: '호텔 코드', body: 'CJUJU'),
          PointHotelInfoItem(
              title: '브랜드', body: 'JW Marriott / Marriott Bonvoy'),
          PointHotelInfoItem(title: '전화', body: '+82 64-803-7777'),
          PointHotelInfoItem(
              title: '좌표', body: '33.24287671066911, 126.5381842623015'),
        ],
      ),
      PointHotelInfoSection(
        title: '정책',
        items: [
          PointHotelInfoItem(title: '체크인/체크아웃', body: '15:00 체크인, 11:00 체크아웃'),
          PointHotelInfoItem(title: '반려동물', body: '반려동물 동반 불가. 안내견은 예외입니다.'),
          PointHotelInfoItem(title: '결제', body: '신용카드와 현금 결제 가능'),
        ],
      ),
      PointHotelInfoSection(
        title: '주차와 교통',
        items: [
          PointHotelInfoItem(title: '주차', body: '호텔 내 무료 주차, 장기 주차 제공'),
          PointHotelInfoItem(
              title: '발레파킹', body: '일일 25,000원. 제휴 프리미엄 카드 무료 발레파킹 안내 포함'),
          PointHotelInfoItem(title: '전기차 충전', body: '전기차 충전소 이용 가능'),
          PointHotelInfoItem(
              title: '가까운 공항',
              body: 'Jeju International Airport(CJU), 호텔에서 약 40.0 km'),
        ],
      ),
    ],
    pointCalendarNote:
        '호텔 정적 정보는 Marriott 페이지에서 추출했고, 차감 포인트와 현금가는 화면 검증용 샘플입니다.',
    calendarPoints: [88000, 92000, 95000, 101000, 89000, 97000, 104000],
  ),
  PointHotel(
    id: 'marriott_selmm',
    name: '르메르디앙 서울, 명동',
    city: '서울',
    country: '대한민국',
    address: '중구 명동8나길 38, 서울, 대한민국 04535',
    brand: 'Le Meridien',
    loyaltyProgram: 'Marriott Bonvoy',
    propertyCode: 'SELMM',
    officialUrl:
        'https://www.marriott.com/ko/hotels/selmm-le-meridien-seoul-myeongdong/overview/',
    phone: '+82 2-2184-7000',
    checkInTime: '16:00',
    checkOutTime: '12:00',
    reviewCount: 544,
    latitude: 37.56185866448736,
    longitude: 126.98268302570197,
    mapUrl:
        'https://www.google.com/maps/search/?api=1&query=37.56185866448736,126.98268302570197',
    imageUrl:
        'https://cache.marriott.com/is/image/marriotts7prod/md-selmm-le-salon-suite-a-39900:Wide-Hor?wid=1336&fit=constrain',
    galleryUrls: [
      'https://cache.marriott.com/is/image/marriotts7prod/md-selmm-le-salon-suite-a-39900:Wide-Hor?wid=1336&fit=constrain',
      'https://cache.marriott.com/is/image/marriotts7prod/md-selmm-swimming-pool-40425:Wide-Hor?wid=992&fit=constrain',
      'https://cache.marriott.com/is/image/marriotts7prod/md-selmm-le-meridien-suite-c-10149:Wide-Hor?wid=992&fit=constrain',
      'https://cache.marriott.com/is/image/marriotts7prod/md-selmm-le-salon-suite-a-39900:Pano-Hor?wid=1600&fit=constrain',
    ],
    rating: 4.7,
    pointsPerNight: 52000,
    cashPerNightKrw: 420000,
    guestFavorite: true,
    description:
        '서울 도심 중심에 위치한 르메르디앙 서울 명동은 미드 센추리 모던 콘셉트의 5성급 프리미엄 호텔입니다. N서울타워, 경복궁, 북촌한옥마을 등 주요 관광지와 가까우며, 스위트를 포함한 200개 객실과 AI 음성 인식 객실 제어, 무료 Wi-Fi, 올데이 다이닝 라팔레트 파리, 로비 라운지 르미에르, 베이커리 카페 르물랑, 세련된 이벤트 공간을 갖추고 있습니다.',
    amenities: [
      '레스토랑',
      '피트니스 센터',
      '실내 수영장',
      '미팅룸',
      '무료 Wi-Fi',
      'Club 라운지',
      '전기차 충전소',
      '모바일 키',
    ],
    amenityDetails: [
      PointHotelAmenity(title: '레스토랑', subtitle: 'La Palette Paris 등'),
      PointHotelAmenity(title: '피트니스 센터'),
      PointHotelAmenity(title: '실내 수영장'),
      PointHotelAmenity(title: '미팅룸'),
      PointHotelAmenity(title: '무료 Wi-Fi', subtitle: '투숙객 및 Bonvoy 회원'),
      PointHotelAmenity(title: 'Club 라운지', subtitle: '엘리트 멤버 및 대상 객실'),
      PointHotelAmenity(title: '비즈니스 센터'),
      PointHotelAmenity(title: '편의점'),
      PointHotelAmenity(title: '당일 드라이클리닝'),
      PointHotelAmenity(title: '호텔 내 세탁 시설'),
      PointHotelAmenity(title: '룸 서비스'),
      PointHotelAmenity(title: '모닝콜'),
      PointHotelAmenity(title: '모바일 키'),
      PointHotelAmenity(title: '서비스 요청'),
    ],
    detailSections: [
      PointHotelInfoSection(
        title: '호텔 기본 정보',
        items: [
          PointHotelInfoItem(title: '호텔 코드', body: 'SELMM'),
          PointHotelInfoItem(
              title: '브랜드', body: 'Le Meridien / Marriott Bonvoy'),
          PointHotelInfoItem(title: '전화', body: '+82 2-2184-7000'),
          PointHotelInfoItem(
              title: '좌표', body: '37.56185866448736, 126.98268302570197'),
        ],
      ),
      PointHotelInfoSection(
        title: '정책',
        items: [
          PointHotelInfoItem(title: '체크인/체크아웃', body: '16:00 체크인, 12:00 체크아웃'),
          PointHotelInfoItem(title: '반려동물', body: '반려동물 동반 불가'),
          PointHotelInfoItem(
              title: '라운지',
              body: 'Club 라운지 운영. 플래티넘, 티타늄, 앰배서더 엘리트 멤버는 투숙 기간 무료 이용 가능'),
        ],
      ),
      PointHotelInfoSection(
        title: '주차와 교통',
        items: [
          PointHotelInfoItem(title: '주차', body: '호텔 내 무료 주차'),
          PointHotelInfoItem(
              title: '발레파킹', body: '투숙당 25,000원. 입출차 가능, 제휴 신용카드 안내 포함'),
          PointHotelInfoItem(title: '전기차 충전', body: '전기차 충전소 이용 가능'),
          PointHotelInfoItem(
              title: '가까운 공항',
              body: 'Gimpo International Airport(GMP), 호텔에서 약 19.0 km'),
        ],
      ),
    ],
    pointCalendarNote:
        '2026-05-22부터 2026-07-01까지 Marriott REDEMPTION 캘린더 응답을 반영했습니다.',
    calendarPoints: [61000, 72000, 63000, 60000, 58000, 60000, 69000],
    calendarEntries: [
      PointHotelCalendarEntry(date: '2026-05-22', points: 61000),
      PointHotelCalendarEntry(date: '2026-05-23', points: 72000),
      PointHotelCalendarEntry(date: '2026-05-25', points: 63000),
      PointHotelCalendarEntry(date: '2026-05-26', points: 60000),
      PointHotelCalendarEntry(date: '2026-05-27', points: 58000),
      PointHotelCalendarEntry(date: '2026-05-28', points: 60000),
      PointHotelCalendarEntry(date: '2026-05-29', points: 69000),
      PointHotelCalendarEntry(date: '2026-05-31', points: 57000),
      PointHotelCalendarEntry(date: '2026-06-01', points: 52000),
      PointHotelCalendarEntry(date: '2026-06-02', points: 62000),
      PointHotelCalendarEntry(date: '2026-06-03', points: 61000),
      PointHotelCalendarEntry(date: '2026-06-04', points: 63000),
      PointHotelCalendarEntry(date: '2026-06-05', points: 65000),
      PointHotelCalendarEntry(date: '2026-06-06', points: 66000),
      PointHotelCalendarEntry(date: '2026-06-07', points: 62000),
      PointHotelCalendarEntry(date: '2026-06-08', points: 59000),
      PointHotelCalendarEntry(date: '2026-06-09', points: 60000),
      PointHotelCalendarEntry(date: '2026-06-11', points: 62000),
      PointHotelCalendarEntry(date: '2026-06-12', points: 66000),
      PointHotelCalendarEntry(date: '2026-06-13', points: 69000),
      PointHotelCalendarEntry(date: '2026-06-14', points: 64000),
      PointHotelCalendarEntry(date: '2026-06-16', points: 61000),
      PointHotelCalendarEntry(date: '2026-06-18', points: 62000),
      PointHotelCalendarEntry(date: '2026-06-19', points: 67000),
      PointHotelCalendarEntry(date: '2026-06-20', points: 72000),
      PointHotelCalendarEntry(date: '2026-06-21', points: 62000),
      PointHotelCalendarEntry(date: '2026-06-24', points: 61000),
      PointHotelCalendarEntry(date: '2026-06-26', points: 62000),
      PointHotelCalendarEntry(date: '2026-06-28', points: 60000),
      PointHotelCalendarEntry(date: '2026-06-29', points: 56000),
      PointHotelCalendarEntry(date: '2026-06-30', points: 54000),
      PointHotelCalendarEntry(date: '2026-07-01', points: 56000),
    ],
  ),
  PointHotel(
    id: 'marriott_dpswr',
    name: 'The Westin Resort & Spa Ubud, Bali',
    city: 'Ubud',
    country: 'Indonesia',
    address:
        'Jalan Lod Tunduh, Br. Kengetan, Desa Singakerta, Ubud, Indonesia 80571',
    brand: 'Westin',
    loyaltyProgram: 'Marriott Bonvoy',
    propertyCode: 'DPSWR',
    officialUrl:
        'https://www.marriott.com/en-us/hotels/dpswr-the-westin-resort-and-spa-ubud-bali/overview/',
    phone: '+62 361-301-8989',
    checkInTime: '15:00',
    checkOutTime: '12:00',
    reviewCount: 696,
    latitude: -8.546546,
    longitude: 115.252301,
    mapUrl:
        'https://www.google.com/maps/search/?api=1&query=-8.5465460,115.2523010',
    imageUrl:
        'https://cache.marriott.com/is/image/marriotts7prod/wi-dpswr-lush-greenery-22103:Wide-Hor?wid=1336&fit=constrain',
    galleryUrls: [
      'https://cache.marriott.com/is/image/marriotts7prod/wi-dpswr-lush-greenery-22103:Wide-Hor?wid=1336&fit=constrain',
      'https://cache.marriott.com/is/image/marriotts7prod/wi-dpswr-resort-surrounding-23218:Wide-Hor?wid=992&fit=constrain',
      'https://cache.marriott.com/is/image/marriotts7prod/wi-dpswr-aerial-of-the-westin-ubud-37731:Square?output-quality=70&interpolation=progressive-bilinear&downsize=550px:*',
      'https://cache.marriott.com/is/image/marriotts7prod/wi-dpswr-lush-greenery-22103:Pano-Hor?wid=1600&fit=constrain',
    ],
    rating: 4.7,
    pointsPerNight: 33000,
    cashPerNightKrw: 310000,
    guestFavorite: true,
    description:
        'The Westin Resort & Spa Ubud, Bali는 웰니스와 가족 여행에 초점을 둔 우붓 리조트입니다. 오픈 로비와 바, 우붓 숲과 인피니티 풀 전망, 24시간 WestinWORKOUT Fitness Studio, Heavenly Spa, 리버사이드 Wellness Pavilion, Tall Trees와 Tabia 레스토랑, 4~12세 어린이를 위한 Westin Family 프로그램을 갖추고 있습니다. 객실, 스위트, 빌라에는 자연광, Heavenly Bed, Heavenly Bath, 무료 Wi-Fi가 제공됩니다.',
    amenities: [
      'Sustainability',
      'Restaurant',
      'Fitness Center',
      'Spa',
      'Outdoor Pool',
      'Hot Tub',
      'Complimentary Wi-Fi',
      'Free Breakfast',
    ],
    amenityDetails: [
      PointHotelAmenity(title: 'Sustainability'),
      PointHotelAmenity(
          title: 'Restaurant On-Site', subtitle: 'Tall Trees, Tabia 등'),
      PointHotelAmenity(title: 'Fitness Center', subtitle: 'Complimentary'),
      PointHotelAmenity(title: 'Spa'),
      PointHotelAmenity(title: 'Outdoor Pool', subtitle: 'Complimentary'),
      PointHotelAmenity(title: 'Whirlpool', subtitle: 'Complimentary'),
      PointHotelAmenity(title: 'Meeting Space'),
      PointHotelAmenity(
          title: 'Complimentary Wi-Fi',
          subtitle: 'Free for Marriott Bonvoy Members'),
      PointHotelAmenity(
          title: 'Free Breakfast',
          subtitle: 'American, buffet, continental and hot breakfast'),
      PointHotelAmenity(title: 'Bicycle Rental'),
      PointHotelAmenity(title: 'Gift Shop'),
      PointHotelAmenity(title: 'Same Day Dry Cleaning'),
      PointHotelAmenity(title: 'On-Site Laundry'),
      PointHotelAmenity(title: 'Room Service'),
      PointHotelAmenity(title: '24 Hour Room Service'),
      PointHotelAmenity(title: 'Wake-Up Calls'),
      PointHotelAmenity(title: 'Turndown Service'),
      PointHotelAmenity(title: 'Mobile Key'),
      PointHotelAmenity(title: 'Service Request'),
    ],
    detailSections: [
      PointHotelInfoSection(
        title: '호텔 기본 정보',
        items: [
          PointHotelInfoItem(title: '호텔 코드', body: 'DPSWR'),
          PointHotelInfoItem(title: '브랜드', body: 'Westin / Marriott Bonvoy'),
          PointHotelInfoItem(title: '전화', body: '+62 361-301-8989'),
          PointHotelInfoItem(title: '좌표', body: '-8.5465460, 115.2523010'),
        ],
      ),
      PointHotelInfoSection(
        title: '정책',
        items: [
          PointHotelInfoItem(title: '체크인/체크아웃', body: '15:00 체크인, 12:00 체크아웃'),
          PointHotelInfoItem(title: '반려동물', body: 'Pets Not Allowed'),
          PointHotelInfoItem(title: '결제', body: 'Credit Cards'),
        ],
      ),
      PointHotelInfoSection(
        title: '주차와 교통',
        items: [
          PointHotelInfoItem(title: '주차', body: '무료 호텔 내 주차, 장기 주차, 무료 발레파킹'),
          PointHotelInfoItem(title: '외부 주차', body: 'Kengetan 0.5 KM'),
          PointHotelInfoItem(title: '전기차 충전', body: '전기차 충전소 이용 가능'),
          PointHotelInfoItem(
              title: '가까운 공항',
              body:
                  'I Gusti Ngurah Rai International Airport - Bali(DPS), 약 29.4 KM'),
        ],
      ),
    ],
    pointCalendarNote:
        '호텔 정적 정보는 Marriott 페이지에서 추출했고, 차감 포인트와 현금가는 화면 검증용 샘플입니다.',
    calendarPoints: [33000, 35000, 37000, 42000, 36000, 39000, 45000],
  ),
  PointHotel(
    id: 'accor_sinfs',
    name: 'Fairmont Singapore',
    city: 'Singapore',
    country: 'Singapore',
    address: '80 Bras Basah Road, Singapore',
    brand: 'Accor',
    imageUrl:
        'https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?auto=format&fit=crop&w=1200&q=80',
    galleryUrls: [
      'https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1564501049412-61c2a3083791?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&w=1200&q=80',
    ],
    rating: 4.5,
    pointsPerNight: 28500,
    cashPerNightKrw: 438000,
    guestFavorite: true,
    description:
        '싱가포르 도심에 있는 아코르 계열 더미 호텔입니다. 현금가와 ALL 포인트 사용 가치를 같이 비교하기 좋은 후보입니다.',
    amenities: ['수영장', '라운지', '쇼핑 접근', '가족 여행'],
    calendarPoints: [28500, 30000, 32000, 36000, 28500, 31000, 34000],
  ),
  PointHotel(
    id: 'hyatt_bkkzs',
    name: 'Hyatt Place Bangkok Sukhumvit',
    city: 'Bangkok',
    country: 'Thailand',
    address: '22/5 Sukhumvit 24, Khlong Toei, Bangkok, Thailand',
    brand: 'Hyatt Place',
    imageUrl:
        'https://images.unsplash.com/photo-1568084680786-a84f91d1153c?auto=format&fit=crop&w=1200&q=80',
    galleryUrls: [
      'https://images.unsplash.com/photo-1568084680786-a84f91d1153c?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1551632436-cbf8dd35adfa?auto=format&fit=crop&w=1200&q=80',
    ],
    rating: 4.4,
    pointsPerNight: 8000,
    cashPerNightKrw: 156000,
    guestFavorite: false,
    description:
        '방콕 수쿰윗 중심에 있는 하얏트 플레이스 스타일의 더미 호텔입니다. 쇼핑과 맛집 동선이 짧아 가족 여행에도 맞습니다.',
    amenities: ['수영장', '피트니스', '루프탑 바', '역세권'],
    calendarPoints: [8000, 8000, 9500, 12000, 8000, 8500, 9000],
  ),
];
