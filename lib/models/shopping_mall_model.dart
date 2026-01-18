class ShoppingMall {
  final String id;
  final String name;
  final String iconPath;
  final String url;
  final int peanutReward; // 획득 가능한 땅콩 개수

  ShoppingMall({
    required this.id,
    required this.name,
    required this.iconPath,
    required this.url,
    required this.peanutReward,
  });

  static List<ShoppingMall> getShoppingMalls() {
    return [
      ShoppingMall(
        id: '11street',
        name: '11번가',
        iconPath: 'asset/icon/11street.png',
        url: 'http://app.ac/8tpTPEM13',
        peanutReward: 5,
      ),
      ShoppingMall(
        id: 'agoda',
        name: '아고다',
        iconPath: 'asset/icon/agoda.png',
        url: 'http://app.ac/XE6uiyS23',
        peanutReward: 8,
      ),
      ShoppingMall(
        id: 'ali',
        name: '알리',
        iconPath: 'asset/icon/ali.png',
        url: 'https://www.aliexpress.com',
        peanutReward: 10,
      ),
      ShoppingMall(
        id: 'auction',
        name: '옥션',
        iconPath: 'asset/icon/auction.png',
        url: 'http://app.ac/5qGNrE273',
        peanutReward: 5,
      ),
      ShoppingMall(
        id: 'coupang',
        name: '쿠팡',
        iconPath: 'asset/icon/coupang.png',
        url: 'https://link.coupang.com/a/du0zfD',
        peanutReward: 7,
      ),
      ShoppingMall(
        id: 'ddang',
        name: '땡처리닷컴',
        iconPath: 'asset/icon/ddang.png',
        url: 'http://app.ac/DjMRXBa33',
        peanutReward: 6,
      ),
      ShoppingMall(
        id: 'gmarket',
        name: '지마켓',
        iconPath: 'asset/icon/gmarket.png',
        url: 'http://app.ac/33r25mJ03',
        peanutReward: 5,
      ),
      ShoppingMall(
        id: 'hotelscombine',
        name: '호텔스컴바인',
        iconPath: 'asset/icon/hotelscombine.png',
        url: 'http://app.ac/XE6uiQS23',
        peanutReward: 8,
      ),
      ShoppingMall(
        id: 'kyobo',
        name: '교보문고',
        iconPath: 'asset/icon/kyobo.png',
        url: 'http://app.ac/mAw9Id583',
        peanutReward: 4,
      ),
      ShoppingMall(
        id: 'ohouse',
        name: '오늘의집',
        iconPath: 'asset/icon/ohouse.png',
        url: 'https://www.ohouse.kr',
        peanutReward: 6,
      ),
      ShoppingMall(
        id: 'sumgo',
        name: '숨고',
        iconPath: 'asset/icon/sumgo.png',
        url: 'http://app.ac/TtpTPhM23',
        peanutReward: 5,
      ),
      ShoppingMall(
        id: 'trip',
        name: '트립닷컴',
        iconPath: 'asset/icon/trip.png',
        url: 'http://app.ac/btpTPUM23',
        peanutReward: 9,
      ),
      ShoppingMall(
        id: 'yes24',
        name: 'yes24',
        iconPath: 'asset/icon/yes24.png',
        url: 'http://app.ac/J3r257J93',
        peanutReward: 4,
      ),
      ShoppingMall(
        id: 'youngpung',
        name: '영풍문고',
        iconPath: 'asset/icon/youngpung.png',
        url: 'http://app.ac/A3r25hJ63',
        peanutReward: 4,
      ),
    ];
  }
}
