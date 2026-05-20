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
  });

  String get locationText => '$city, $country';

  String get hostText => '$brand이(가) 호스팅';

  double get krwPerPoint => cashPerNightKrw / pointsPerNight;

  String get searchableText {
    return [
      name,
      city,
      country,
      address,
      brand,
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
    id: 'marriott_lhrwm',
    name: 'The Westin London City',
    city: 'London',
    country: 'United Kingdom',
    address: '60 Upper Thames Street, London EC4V 3AD, United Kingdom',
    brand: 'Marriott',
    imageUrl:
        'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80',
    galleryUrls: [
      'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80',
    ],
    rating: 4.6,
    pointsPerNight: 40000,
    cashPerNightKrw: 612000,
    guestFavorite: true,
    description:
        '템스강과 세인트폴 대성당 사이에 있는 메리어트 계열 더미 호텔입니다. 런던 성수기 현금가가 높을 때 포인트 가치가 돋보입니다.',
    amenities: ['스파', '수영장', '라운지', '강변 위치'],
    calendarPoints: [40000, 42000, 52000, 65000, 40000, 48000, 58000],
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
