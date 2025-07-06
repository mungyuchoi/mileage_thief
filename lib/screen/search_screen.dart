import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mileage_thief/helper/AdHelper.dart';
import 'package:mileage_thief/screen/dan_screen.dart';
import 'package:mileage_thief/screen/detail/search_detail__round_screen.dart';
import 'package:mileage_thief/screen/detail/search_detail_one_way_screen.dart';
import 'package:mileage_thief/screen/login_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../custom/CustomDropdownButton2.dart';
import '../model/search_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:share_plus/share_plus.dart';
import '../model/search_history.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../screen/community_screen.dart';

class SearchScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _SearchScreenState();
}

const double width = 150.0;
const double height = 50.0;
const double loginAlign = -1;
const double signInAlign = 1;
const Color selectedColor = Colors.white;
const Color normalColor = Colors.white;

class _SearchScreenState extends State<SearchScreen> {
  GlobalKey<_AirportScreenState> airportScreenKey = GlobalKey();
  int _currentIndex = 0;
  final DatabaseReference _versionReference =
  FirebaseDatabase.instance.ref("VERSION");
  
  // 공지사항 제목을 저장할 변수
  String _communityNoticeTitle = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    getVersion();
    _loadVersionFirebase();
    _loadCommunityNoticeTitle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(242, 242, 247, 1.0),
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? '${_communityNoticeTitle.isNotEmpty ? ' $_communityNoticeTitle' : ''}'
              : _currentIndex == 1
                  ? '대한항공 마일리지 찾기'
                  : _currentIndex == 2
                      ? '아시아나 마일리지 찾기'
                      : '설정',
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
        leading: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Image.asset(
              'asset/img/app_icon.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black54),
            onPressed: () {
              String appLink = '';
              if (Platform.isAndroid) {
                appLink =
                    'https://play.google.com/store/apps/details?id=com.mungyu.mileage_thief';
              } else {
                appLink = 'https://apps.apple.com/app/myapp/6446247689';
              }
              String description = "마일리지 항공 앱을 공유해보세요! $appLink";
              SharePlus.instance.share(ShareParams(text: description));
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat, color: Colors.black54),
            onPressed: _launchOpenChat,
          ),
        ],
      ),
      body: buildPage(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.grey[100],
        currentIndex: _currentIndex,
        selectedItemColor: Colors.black54,
        unselectedItemColor: Colors.black38,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.people_outline_sharp),
                SizedBox(height: 2),
                Text('커뮤니티', style: TextStyle(fontSize: 12)),
              ],
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.airlines),
                SizedBox(height: 2),
                Text('대한항공', style: TextStyle(fontSize: 12)),
              ],
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.airlines),
                SizedBox(height: 2),
                Text('아시아나', style: TextStyle(fontSize: 12)),
              ],
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.settings),
                SizedBox(height: 2),
                Text('설정', style: TextStyle(fontSize: 12)),
              ],
            ),
            label: '',
          ),
        ],
      ),
    );
  }

  Widget buildPage(int index) {
    switch (index) {
      case 0:
        return const CommunityScreen();
      case 1:
        return buildDanWidget();
      case 2:
        return buildAsianaWidget();
      case 3:
        return buildSettingsWidget();
      default:
        return const CommunityScreen();
    }
  }

  Widget buildAsianaWidget() {
    return Stack(
      children: [
        // 1. 기존 UI 흐릿하게 보이도록
        SingleChildScrollView(
          child: AirportScreen(key: airportScreenKey),
        ),
        // 2. 반투명 안개 레이어
        Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white.withOpacity(0.85),
        ),
        // 3. 안내 문구
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.cloud, size: 60, color: Colors.black54),
              SizedBox(height: 24),
              Text(
                '아시아나 기능은 안정화된 이후에 오픈됩니다.',
                style: TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildDanWidget() {
    return FutureBuilder<InitializationStatus>(
      future: _initGoogleMobileAds(),
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        return const SingleChildScrollView(
          child: SearchDanScreen(),
        );
      },
    );
  }

  bool _notificationToggle = true;
  String _version = '';
  String _latestVersion = '';

  Widget buildSettingsWidget() {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: AuthService.authStateChanges,
        builder: (context, snapshot) {
          final user = snapshot.data;
          
          return SettingsList(
            platform: DevicePlatform.iOS,
            sections: [
              SettingsSection(
                tiles: [
                  SettingsTile.switchTile(
                    initialValue: _notificationToggle,
                    onToggle: (bool value) {
                      setNotificationToggle(value);
                      setState(() {
                        _notificationToggle = value;
                      });
                    },
                    title: const Text('알림'),
                    description: const Text('마일리지 캐치 알림'),
                    leading: const Icon(Icons.notifications_none),
                    activeSwitchColor: Colors.black54,
                  ),
                  SettingsTile(
                    onPressed: (context) => {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      )
                    },
                    title: Text(user == null ? '로그인' : '내 정보'),
                    description: Text(user == null 
                      ? '로그인하여 땅콩을 클라우드에 저장하세요'
                      : '${user.displayName ?? user.email ?? "사용자"}님, 안녕하세요!'),
                    leading: Icon(user == null ? Icons.login : Icons.account_circle_outlined),
                  ),
                  SettingsTile(
                    onPressed: (context) => {
                      _launchMileageThief(AdHelper.mileageTheifMarketUrl)
                    },
                    title: const Text("스토어로 이동"),
                    leading: const Icon(Icons.info_outline),
                  ),
                  SettingsTile(
                    onPressed: (context) => {
                      _version == _latestVersion
                          ? Fluttertoast.showToast(
                              msg: "최신버전입니다.",
                              gravity: ToastGravity.BOTTOM,
                              timeInSecForIosWeb: 5,
                              backgroundColor: Colors.black38,
                              fontSize: 20,
                              textColor: Colors.white,
                              toastLength: Toast.LENGTH_SHORT,
                            )
                          : Fluttertoast.showToast(
                              msg: "최신버전이 아닙니다. 업데이트 부탁드립니다.",
                              gravity: ToastGravity.BOTTOM,
                              timeInSecForIosWeb: 5,
                              backgroundColor: Colors.black38,
                              fontSize: 20,
                              textColor: Colors.white,
                              toastLength: Toast.LENGTH_SHORT,
                            )
                    },
                    title: const Text('버전 정보'),
                    description: Text(_version == _latestVersion
                        ? 'Version: $_version (최신버전입니다.)'
                        : 'Version: $_version (최신버전이 아닙니다.)'),
                    leading: const Icon(Icons.info_outline),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<InitializationStatus> _initGoogleMobileAds() {
    return MobileAds.instance.initialize();
  }

  Future<void> getVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  void _launchOpenChat() async {
    const url = 'https://open.kakao.com/o/grMdcJ7e';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void setNotificationToggle(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification', value);
    Fluttertoast.showToast(
      msg: value ? "알림을 켰습니다." : "알림을 껐습니다.",
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 5,
      backgroundColor: Colors.black38,
      fontSize: 20,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  void _loadVersionFirebase() {
    _versionReference.once().then((event) {
      final snapshot = event.snapshot;
      Map<dynamic, dynamic>? values = snapshot.value as Map<dynamic, dynamic>?;
      if (values != null) {
        values.forEach((key, value) {
          _latestVersion = value;
        });
        setState(() {});
      }
    });
  }

  void _loadCommunityNoticeTitle() async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('notice')
          .doc('community')
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _communityNoticeTitle = data['title'] ?? '';
        });
      }
    } catch (e) {
      print('공지사항 제목 로드 실패: $e');
    }
  }

  _launchMileageThief(String mileageTheifMarketUrl) async {
    String appLink;
    if (Platform.isAndroid) {
      appLink = 'https://play.google.com/store/apps/details?id=com.mungyu.mileage_thief';
    } else {
      appLink = 'https://apps.apple.com/app/myapp/6446247689';
    }
    
    if (await canLaunch(appLink)) {
      await launch(appLink);
    } else {
      throw '마켓을 열 수 없습니다: $appLink';
    }
  }
}

class AirportScreen extends StatefulWidget {
  const AirportScreen({super.key});

  @override
  State<StatefulWidget> createState() => _AirportScreenState();
}

class _AirportScreenState extends State<AirportScreen> {
  double xAlign = 5.0;
  Color loginColor = Colors.black;
  Color signInColor = Colors.black;
  List<String> airportItems = [];
  String? dateSelectedValue = "전체";
  String? departureSelectedValue = "서울|인천-ICN";
  String? arrivalSelectedValue;
  bool _arrivalError = false;
  late BannerAd _banner;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  final DatabaseReference _countryReference =
      FirebaseDatabase.instance.ref("COUNTRY");
  int startMonth = DateTime.now().month, startYear = DateTime.now().year;
  int endMonth = DateTime.now().month, endYear = DateTime.now().year + 1;
  int firstEnableMonth = DateTime.now().month,
      lastEnableMonth = DateTime.now().month;
  int _counter = 3;
  bool isLoading = false;
  List<SearchHistory> searchHistory = [];

  @override
  void initState() {
    super.initState();
    _loadCounter();
    _loadCountryFirebase();
    xAlign = loginAlign;
    loginColor = selectedColor;
    signInColor = normalColor;

    _banner = BannerAd(
      listener: BannerAdListener(
        onAdFailedToLoad: (Ad ad, LoadAdError err) {
          FirebaseAnalytics.instance
              .logEvent(name: "banner", parameters: {'error': err.message});
        },
        onAdLoaded: (_) {},
      ),
      size: AdSize.banner,
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
    )..load();
    _loadRewardedAd();
  }

  _loadCounter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _counter = (prefs.getInt('counter') ?? 3);
    });
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              setState(() {
                ad.dispose();
                _rewardedAd = null;
              });
              _loadRewardedAd();
            },
          );

          setState(() {
            _rewardedAd = ad;
          });
        },
        onAdFailedToLoad: (err) {
          print('Failed to load a rewarded ad: ${err.message}');
          FirebaseAnalytics.instance
              .logEvent(name: "rewards", parameters: {'error': err.message});
        },
      ),
    );
  }

  void _loadCountryFirebase() {
    print("loadCountryFirebase!");
    _countryReference.once().then((event) {
      final snapshot = event.snapshot;
      Map<dynamic, dynamic>? values = snapshot.value as Map<dynamic, dynamic>?;
      if (values != null) {
        airportItems.clear();
        values.forEach((key, value) {
          airportItems.add(key);
        });
        airportItems.remove("서울|인천-ICN");
        airportItems.insert(0, "서울|인천-ICN");
        setState(() {});
      }
    });
  }

  Future<void> showFrontAd() async {
    isLoading = true;
    setState(() {});
    InterstitialAd.load(
      adUnitId: AdHelper.frontBannerAdUnitId,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              _incrementCounter(2);
              isLoading = false;
              setState(() {});
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              ad.dispose();
              isLoading = false;
              setState(() {});
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (LoadAdError error) {
          isLoading = false;
          setState(() {});
        },
      ),
    );
  }

  void showRewardsAd() {
    print("showRewardsAd _rewardedAd:$_rewardedAd");
    _rewardedAd?.show(onUserEarnedReward: (_, reward) {
      _incrementCounter(10);
    });
  }

  _incrementCounter(int peanuts) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _counter = (prefs.getInt('counter') ?? 0) + peanuts;
      prefs.setInt('counter', _counter);
      
      // 로그인 상태 확인 후 Firestore 업데이트
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        UserService.updatePeanutCount(currentUser.uid, _counter).catchError((error) {
          print('Firestore 업데이트 오류: $error');
        });
      }
      
      Fluttertoast.showToast(
        msg: "땅콩 $peanuts개를 얻었습니다.",
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 5,
        backgroundColor: Colors.black38,
        fontSize: 20,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_SHORT,
      );
    });
  }

  _decrementCounter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _counter--;
      prefs.setInt('counter', _counter);
    });
  }

  bool useCounter() {
    if (_counter <= 0) {
      Fluttertoast.showToast(
        msg: "땅콩(광고) 버튼을 선택하여 땅콩을 얻으세요!",
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black38,
        fontSize: 13,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_SHORT,
      );
      return false;
    }
    setState(() {
      _decrementCounter();
    });
    return true;
  }

  @override
  void dispose() {
    _banner.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: width,
          height: height,
          margin: const EdgeInsets.only(top: 30),
          decoration: const BoxDecoration(
            color: Color(0x80D60815),
            borderRadius: BorderRadius.all(
              Radius.circular(50.0),
            ),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                alignment: Alignment(xAlign, 0),
                duration: Duration(milliseconds: 300),
                child: Container(
                  width: width * 0.5,
                  height: height,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD60815),
                    borderRadius: BorderRadius.all(
                      Radius.circular(50.0),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    xAlign = loginAlign;
                    loginColor = selectedColor;
                    signInColor = normalColor;
                  });
                },
                child: Align(
                  alignment: Alignment(-1, 0),
                  child: Container(
                    width: width * 0.5,
                    color: Colors.transparent,
                    alignment: Alignment.center,
                    child: Text(
                      '편도',
                      style: TextStyle(
                        color: loginColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    xAlign = signInAlign;
                    signInColor = selectedColor;
                    loginColor = normalColor;
                  });
                },
                child: Align(
                  alignment: Alignment(1, 0),
                  child: Container(
                    width: width * 0.5,
                    color: Colors.transparent,
                    alignment: Alignment.center,
                    child: Text(
                      '왕복',
                      style: TextStyle(
                        color: signInColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
            padding: const EdgeInsets.all(15),
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: ListView(
              padding: const EdgeInsets.all(4),
              children: <Widget>[
                const Divider(
                  color: Colors.black,
                  thickness: 2,
                ),
                const Padding(padding: EdgeInsets.all(4)),
                Row(
                  children: [
                    Expanded(
                      child: CustomDropdownButton2(
                        hint: '어디서 가나요?',
                        dropdownWidth: 180,
                        dropdownItems: airportItems,
                        hintAlignment: Alignment.center,
                        value: departureSelectedValue,
                        scrollbarAlwaysShow: true,
                        scrollbarThickness: 10,
                        onChanged: (value) {
                          setState(() {
                            departureSelectedValue = value;
                          });
                        },
                      ),
                    ),
                    const Padding(padding: EdgeInsets.all(4)),
                    IconButton(
                      icon: const Icon(Icons.loop_sharp, color: Colors.black54),
                      onPressed: () {
                        setState(() {
                          var tempValue = departureSelectedValue;
                          departureSelectedValue = arrivalSelectedValue;
                          arrivalSelectedValue = tempValue;
                        });
                      },
                    ),
                    const Padding(padding: EdgeInsets.all(4)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomDropdownButton2(
                            hint: '어디로 가나요?',
                            dropdownWidth: 180,
                            hintAlignment: Alignment.center,
                            dropdownItems: airportItems,
                            value: arrivalSelectedValue,
                            scrollbarAlwaysShow: true,
                            scrollbarThickness: 10,
                            onChanged: (value) {
                              setState(() {
                                arrivalSelectedValue = value;
                                _arrivalError = false;
                              });
                            },
                          ),
                          if (_arrivalError)
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0, top: 4.0),
                              child: Text(
                                '도착지를 선택하세요.',
                                style: TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.all(4)),
                const Divider(
                  color: Colors.black,
                  thickness: 2,
                ),
                if (searchHistory.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: searchHistory.map((h) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              departureSelectedValue = h.departure;
                              arrivalSelectedValue = h.arrival;
                              startYear = h.startYear;
                              startMonth = h.startMonth;
                              endYear = h.endYear;
                              endMonth = h.endMonth;
                            });
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${h.departure} - ${h.arrival}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                                      Text('${h.startYear}.${h.startMonth} ~ ${h.endYear}.${h.endMonth}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.black54),
                                splashRadius: 10,
                                onPressed: () {
                                  setState(() {
                                    searchHistory.remove(h);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.all(4)),
                  const Divider(
                    color: Colors.black,
                    thickness: 2,
                  ),
                ],
                const Padding(padding: EdgeInsets.all(4)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 10),
                    ElevatedButton(
                        onPressed: () async {
                          final selected = await showMonthPicker(
                            context: context,
                            initialDate: DateTime(startYear, startMonth),
                            firstDate: DateTime(DateTime.now().year, 1),
                            lastDate: DateTime(DateTime.now().year + 1, 12),
                            monthPickerDialogSettings: MonthPickerDialogSettings(
                              dialogSettings: PickerDialogSettings(
                                dialogBackgroundColor: Colors.white,
                                locale: Locale('ko'),
                              ),
                              headerSettings: PickerHeaderSettings(
                                headerBackgroundColor: Color(0xFFD60815),
                              ),
                              dateButtonsSettings: PickerDateButtonsSettings(
                                unselectedMonthsTextColor: Colors.black,
                                selectedMonthTextColor: Colors.black,
                                currentMonthTextColor: Colors.black,
                              ),
                              actionBarSettings: PickerActionBarSettings(
                                confirmWidget: Text(
                                  '확인',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                cancelWidget: Text(
                                  '취소',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                          if (selected != null) {
                            setState(() {
                              startYear = selected.year;
                              startMonth = selected.month;
                            });
                          }
                        },
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.white, backgroundColor: Color(0x80D60815),
                            minimumSize: const Size(110, 40)),
                        child: Text(
                          "시작일 $startYear년 $startMonth월",
                          style: const TextStyle(fontSize: 13),
                        )),
                    const SizedBox(width: 10),
                    ElevatedButton(
                        onPressed: () async {
                          final selected = await showMonthPicker(
                            context: context,
                            initialDate: DateTime(endYear, endMonth),
                            firstDate: DateTime(DateTime.now().year, 1),
                            lastDate: DateTime(DateTime.now().year + 1, 12),
                            monthPickerDialogSettings: MonthPickerDialogSettings(
                              dialogSettings: PickerDialogSettings(
                                dialogBackgroundColor: Colors.white,
                                locale: Locale('ko'),
                              ),
                              headerSettings: PickerHeaderSettings(
                                headerBackgroundColor: Color(0xFFD60815),
                              ),
                              dateButtonsSettings: PickerDateButtonsSettings(
                                unselectedMonthsTextColor: Colors.black,
                                selectedMonthTextColor: Colors.black,
                                currentMonthTextColor: Colors.black,
                              ),
                              actionBarSettings: PickerActionBarSettings(
                                confirmWidget: Text(
                                  '확인',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                cancelWidget: Text(
                                  '취소',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                          if (selected != null) {
                            setState(() {
                              endYear = selected.year;
                              endMonth = selected.month;
                            });
                          }
                        },
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.white, backgroundColor: Color(0x80D60815),
                            minimumSize: const Size(110, 40)),
                        child: Text(
                          "종료일 $endYear년 $endMonth월",
                          style: const TextStyle(fontSize: 13),
                        )),
                  ],
                ),
                const Padding(padding: EdgeInsets.all(4)),
                const Divider(
                  color: Colors.black,
                  thickness: 2,
                ),
                Text(
                  '땅콩: $_counter개',
                  style: const TextStyle(fontSize: 18, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const Padding(padding: EdgeInsets.all(3)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton.extended(
                      onPressed: () async {
                        if (isLoading) {
                          Fluttertoast.showToast(
                            msg: "아직 준비되지 않았습니다. 조금 있다가 다시 시도해보세요",
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.black54,
                            textColor: Colors.white,
                          );
                          return;
                        }
                        await showFrontAd();
                      },
                      label: const Text("+ 2",
                          style: TextStyle(color: Colors.black87)),
                      backgroundColor: Colors.white,
                      elevation: 3,
                      icon: Image.asset(
                        'asset/img/peanut.png',
                        scale: 19,
                      ),
                    ),
                    FloatingActionButton.extended(
                      onPressed: () {
                        showRewardsAd();
                      },
                      label: const Text("+ 10",
                          style: TextStyle(color: Colors.black87)),
                      backgroundColor: Colors.white,
                      elevation: 3,
                      icon: Image.asset(
                        'asset/img/peanuts.png',
                        scale: 19,
                      ),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.all(3)),
                const Text("🥜 광고로 땅콩 받는 기능은 잠시 휴식 중이에요! \n 다른 기회를 통해 땅콩을 사용하는 재미를 준비하고 있어요.", textAlign: TextAlign.center),
                const Padding(padding: EdgeInsets.all(3)),
                ElevatedButton(
                  onPressed: () {
                    if (arrivalSelectedValue == null || arrivalSelectedValue!.isEmpty) {
                      setState(() {
                        _arrivalError = true;
                      });
                      Fluttertoast.showToast(
                        msg: "도착지를 선택해주세요.",
                        gravity: ToastGravity.BOTTOM,
                        backgroundColor: Colors.black54,
                        textColor: Colors.white,
                      );
                      return;
                    }
                    if (departureSelectedValue == null || departureSelectedValue!.isEmpty) {
                      Fluttertoast.showToast(
                        msg: "출발지를 선택해주세요.",
                        gravity: ToastGravity.BOTTOM,
                        backgroundColor: Colors.black54,
                        textColor: Colors.white,
                      );
                      return;
                    }
                    if (xAlign == -1.0) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  SearchDetailScreen(SearchModel(
                                    isRoundTrip: xAlign == -1.0 ? true : false,
                                    departureAirport: departureSelectedValue,
                                    arrivalAirport: arrivalSelectedValue,
                                    seatClass: '',
                                    searchDate: dateSelectedValue,
                                    startMonth:
                                        startMonth.toString().padLeft(2, '0'),
                                    startYear: startYear.toString(),
                                    endMonth:
                                        endMonth.toString().padLeft(2, '0'),
                                    endYear: endYear.toString(),
                                  ))));
                    } else {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SearchDetailRoundScreen(
                                  SearchModel(
                                      isRoundTrip:
                                          xAlign == -1.0 ? true : false,
                                      departureAirport: departureSelectedValue,
                                      arrivalAirport: arrivalSelectedValue,
                                      seatClass: '',
                                      searchDate: dateSelectedValue,
                                      startMonth:
                                          startMonth.toString().padLeft(2, '0'),
                                      startYear: startYear.toString(),
                                      endMonth:
                                          endMonth.toString().padLeft(2, '0'),
                                      endYear: endYear.toString()))));
                    }
                    // 히스토리 추가
                    final newHistory = SearchHistory(
                      departure: departureSelectedValue ?? '',
                      arrival: arrivalSelectedValue ?? '',
                      startYear: startYear,
                      startMonth: startMonth,
                      endYear: endYear,
                      endMonth: endMonth,
                    );
                    setState(() {
                      searchHistory.remove(newHistory); // 중복 제거
                      searchHistory.insert(0, newHistory); // 맨 앞에 추가
                      if (searchHistory.length > 3) {
                        searchHistory = searchHistory.sublist(0, 3);
                      }
                    });
                  },
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.white, backgroundColor: const Color(0xFFD60815),
                      minimumSize: const Size.fromHeight(56.0)),
                  child: const Text(
                    "검색하기",
                    style: TextStyle(fontSize: 18),
                  ),
                )
              ],
            )),
      ],
    );
  }
}
