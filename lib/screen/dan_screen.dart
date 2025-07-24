import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mileage_thief/helper/AdHelper.dart';
import 'package:mileage_thief/screen/detail/search_detail_dan_one_way_screen.dart';
import 'package:mileage_thief/screen/detail/search_detail_dan_round_screen.dart';
import 'package:mileage_thief/screen/cancellation_notification_screen.dart';
import '../custom/CustomDropdownButton2.dart';
import '../model/search_model.dart';
import '../model/search_history.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class SearchDanScreen extends StatefulWidget {
  const SearchDanScreen({super.key});

  @override
  State<StatefulWidget> createState() => _SearchDanScreen();
}

const double width = 150.0;
const double height = 50.0;
const double loginAlign = -1;
const double signInAlign = 1;
const Color selectedColor = Colors.white;
const Color normalColor = Colors.white;

// 전역 스크린샷 모드 변수
bool isScreenShotMode = false;

class _SearchDanScreen extends State<SearchDanScreen> {
  double xAlign = 5.0;
  Color loginColor = Colors.black;
  Color signInColor = Colors.black;
  List<String> airportItems = [];
  String? dateSelectedValue = "전체";
  String? classSelectedValue = "비즈니스";
  String? departureSelectedValue = "서울|인천-ICN";
  String? arrivalSelectedValue;
  bool _arrivalError = false;
  late BannerAd _banner;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  final DatabaseReference _countryReference =
  FirebaseDatabase.instance.ref("COUNTRY_DAN");
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
      adUnitId: AdHelper.bannerDanAdUnitId,
      request: const AdRequest(),
    )..load();
    _loadRewardedAd();
    _loadFullScreenAd();
  }
  _loadFullScreenAd() {
    print('전면광고 로드 시도');
    InterstitialAd.load(
      adUnitId: AdHelper.frontBannerDanAdUnitId,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          print('전면광고 로드 성공! ad: ' + ad.toString());
          setState(() {
            _interstitialAd = ad;
          });
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('전면광고 로드 실패: $error');
          setState(() {
            _interstitialAd = null;
          });
        },
      ),
    );
    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        _loadFullScreenAd();
        print('%ad onAdShowedFullScreenContent.');
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('$ad onAdDismissedFullScreenContent.');
        setState(() {
          ad.dispose();
        });
        _loadFullScreenAd();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('$ad onAdFailedToShowFullScreenContent: $error');
        _incrementCounter(10);
        setState(() {
          ad.dispose();
        });
        _loadFullScreenAd();
      },
      onAdImpression: (InterstitialAd ad) => print('$ad impression occurred.'),
    );
    _interstitialAd?.show();
  }

  _loadCounter() async {
    final currentUser = AuthService.currentUser;
    
    if (currentUser != null) {
      // 로그인한 사용자: Firestore에서 peanutCount 가져오기
      try {
        final userData = await UserService.getUserFromFirestoreWithLimit(currentUser.uid);
        setState(() {
          _counter = userData?['peanutCount'] ?? 0;
        });
      } catch (error) {
        print('Firestore에서 peanutCount 로드 오류: $error');
        // Firestore 실패 시 SharedPreferences를 fallback으로 사용
        SharedPreferences prefs = await SharedPreferences.getInstance();
        setState(() {
          _counter = (prefs.getInt('counter') ?? 3);
        });
      }
    } else {
      // 로그인하지 않은 사용자: SharedPreferences 사용
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _counter = (prefs.getInt('counter') ?? 3);
      });
    }
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: AdHelper.rewardedDanAdUnitId,
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
    _loadFullScreenAd();
    print("showFrontAd _:$_interstitialAd" );
    _interstitialAd?.show();
    // await _incrementCounter(2);
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
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.grey[800],
        textColor: Colors.white,
        fontSize: 16.0,
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
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.grey[800],
        textColor: Colors.white,
        fontSize: 16.0,
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
    print('빌드: _interstitialAd =  [33m [1m [4m [7m' + (_interstitialAd == null ? 'null' : '존재') + '\u001b[0m');
    return SingleChildScrollView(
      child: Column(
        children: [
          // 상단 알림 버튼 영역
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 20, right: 16, left: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CancellationNotificationScreen(),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.notifications_outlined,
                        color: Color(0xFF00256B),
                        size: 28,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '취소표 알림',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF00256B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: width,
            height: height,
            margin: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              color: Color(0x8000256B),
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
                      color: Color(0xFF00256B),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                              child: Text(
                                (arrivalSelectedValue == null || arrivalSelectedValue!.isEmpty)
                                    ? '도착지를 선택하세요.'
                                    : (departureSelectedValue == arrivalSelectedValue)
                                        ? '출발지와 도착지가 같을 수 없습니다.'
                                        : '도착지에 문제가 있습니다.',
                                style: const TextStyle(color: Colors.red, fontSize: 12),
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
                                headerBackgroundColor: Color(0x8000256B),
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
                            foregroundColor: Colors.white, backgroundColor: Color(0x8000256B),
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
                                headerBackgroundColor: Color(0x8000256B),
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
                            foregroundColor: Colors.white, backgroundColor: Color(0x8000256B),
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
                Center(
                  child: Text(
                    '땅콩: $_counter개',
                    style: const TextStyle(fontSize: 18, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Padding(padding: EdgeInsets.all(3)),
                // 광고 버튼들 (+10, +30)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton.extended(
                      onPressed: _interstitialAd == null || isLoading
                          ? null
                          : () async {
                              print('전면광고 버튼 클릭: _interstitialAd = ' + (_interstitialAd == null ? 'null' : '존재'));
                              final result = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  title: const Text('알림', style: TextStyle(color: Colors.black)),
                                  content: const Text('광고를 시청하고 땅콩을 얻겠습니까?', style: TextStyle(color: Colors.black)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('아니오', style: TextStyle(color: Colors.black)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('예', style: TextStyle(color: Colors.black)),
                                    ),
                                  ],
                                ),
                              );
                              if (result == true) {
                                setState(() { isLoading = true; });
                                try {
                                  print('전면광고 show() 호출');
                                  _interstitialAd?.show();
                                } finally {
                                  setState(() {
                                    isLoading = false;
                                    _interstitialAd = null;
                                  });
                                  print('전면광고 사용 후 _interstitialAd = null, _loadFullScreenAd() 호출');
                                  _loadFullScreenAd();
                                }
                              }
                            },
                      label: const Text("+ 10", style: TextStyle(color: Colors.black87)),
                      backgroundColor: _interstitialAd == null ? Colors.grey[300] : Colors.white,
                      elevation: 3,
                      icon: Image.asset('asset/img/peanut.png', scale: 19),
                    ),
                    FloatingActionButton.extended(
                      onPressed: _rewardedAd == null
                          ? null
                          : () async {
                              final result = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  title: const Text('알림', style: TextStyle(color: Colors.black)),
                                  content: const Text('광고를 시청하고 땅콩을 얻겠습니까?', style: TextStyle(color: Colors.black)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('아니오', style: TextStyle(color: Colors.black)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('예', style: TextStyle(color: Colors.black)),
                                    ),
                                  ],
                                ),
                              );
                              if (result == true) {
                                showRewardsAd();
                                _incrementCounter(30); // 광고 성공 시 +30
                              }
                            },
                      label: const Text("+ 30", style: TextStyle(color: Colors.black87)),
                      backgroundColor: _rewardedAd == null ? Colors.grey[300] : Colors.white,
                      elevation: 3,
                      icon: Image.asset('asset/img/peanuts.png', scale: 19),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.all(7)),
                const Center(
                  child: Text(
                    "땅콩을 모아서 커뮤니티의 다양한 혜택을 누려보세요!",
                    textAlign: TextAlign.center,
                  ),
                ),
                const Padding(padding: EdgeInsets.all(7)),
                ElevatedButton(
                  onPressed: () {
                    // 시작일/종료일 유효성 검사 추가
                    final start = DateTime(startYear, startMonth);
                    final end = DateTime(endYear, endMonth);
                    if (start.isAfter(end)) {
                      Fluttertoast.showToast(
                        msg: "잘못된 시작일과 종료일입니다.",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.grey[800],
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                      return;
                    }
                    // 땅콩 사용하지 않음 (무료)
                    if (arrivalSelectedValue == null || arrivalSelectedValue!.isEmpty) {
                      setState(() {
                        _arrivalError = true;
                      });
                      Fluttertoast.showToast(
                        msg: "도착지를 선택해주세요.",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.grey[800],
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                      return;
                    }
                    if (departureSelectedValue == null || departureSelectedValue!.isEmpty) {
                      Fluttertoast.showToast(
                        msg: "출발지를 선택해주세요.",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.grey[800],
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                      return;
                    }
                    if (departureSelectedValue == arrivalSelectedValue) {
                      setState(() {
                        _arrivalError = true;
                      });
                      Fluttertoast.showToast(
                        msg: "출발지와 도착지가 같을 수 없습니다.",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.grey[800],
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                      return;
                    }
                    if (xAlign == -1.0) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  SearchDetailDanScreen(SearchModel(
                                    isRoundTrip: xAlign == -1.0 ? true : false,
                                    departureAirport: departureSelectedValue,
                                    arrivalAirport: arrivalSelectedValue,
                                    seatClass: classSelectedValue,
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
                              builder: (context) => SearchDetailDanRoundScreen(
                                  SearchModel(
                                      isRoundTrip:
                                      xAlign == -1.0 ? true : false,
                                      departureAirport: departureSelectedValue,
                                      arrivalAirport: arrivalSelectedValue,
                                      seatClass: classSelectedValue,
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
                      foregroundColor: Colors.white, backgroundColor: const Color(0xFF00256B),
                      minimumSize: const Size.fromHeight(56.0)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Align(
                        alignment: Alignment.center,
                        child: Text(
                          "검색하기",
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Builder(
                          builder: (context) {
                            return const Padding(
                              padding: EdgeInsets.only(right: 16.0),
                              child: Text(
                                '땅콩 0개(무료)',
                                style: TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(padding: EdgeInsets.all(16)),
                // 배너 광고 표시
                if (!isScreenShotMode)
                  Container(
                    alignment: Alignment.center,
                    child: AdWidget(ad: _banner),
                    width: double.infinity,
                    height: _banner.size.height.toDouble(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}