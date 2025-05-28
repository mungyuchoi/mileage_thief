import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mileage_thief/helper/AdHelper.dart';
import 'package:mileage_thief/screen/detail/search_detail_dan_one_way_screen.dart';
import 'package:mileage_thief/screen/detail/search_detail_dan_round_screen.dart';
import '../custom/CustomDropdownButton2.dart';
import '../model/search_model.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_custom_month_picker/flutter_custom_month_picker.dart';

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
  }
  _loadFullScreenAd() {
    InterstitialAd.load(
      adUnitId: AdHelper.frontBannerDanAdUnitId,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          this._interstitialAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {},
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
        _incrementCounter(2);
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _counter = (prefs.getInt('counter') ?? 3);
    });
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
                const Padding(padding: EdgeInsets.all(4)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 10),
                    ElevatedButton(
                        onPressed: () {
                          showMonthPicker(context, onSelected: (month, year) {
                            setState(() {
                              startMonth = month;
                              startYear = year;
                            });
                          },
                              initialSelectedMonth: startMonth,
                              initialSelectedYear: startYear,
                              firstEnabledMonth: firstEnableMonth,
                              lastEnabledMonth: lastEnableMonth,
                              firstYear: DateTime.now().year,
                              lastYear: DateTime.now().year + 1,
                              selectButtonText: '확인',
                              cancelButtonText: '취소',
                              highlightColor: Colors.black54,
                              textColor: Colors.black,
                              contentBackgroundColor: Colors.white,
                              dialogBackgroundColor: Colors.grey[200]);
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
                        onPressed: () {
                          showMonthPicker(context, onSelected: (month, year) {
                            setState(() {
                              endMonth = month;
                              endYear = year;
                            });
                          },
                              initialSelectedMonth: endMonth,
                              initialSelectedYear: endYear,
                              firstEnabledMonth: firstEnableMonth,
                              lastEnabledMonth: lastEnableMonth,
                              firstYear: DateTime.now().year,
                              lastYear: DateTime.now().year + 1,
                              selectButtonText: '확인',
                              cancelButtonText: '취소',
                              highlightColor: Colors.black54,
                              textColor: Colors.black,
                              contentBackgroundColor: Colors.white,
                              dialogBackgroundColor: Colors.grey[200]);
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
                        isLoading = true;
                        setState(() {});
                        try {
                          await showFrontAd();
                        } finally {
                          isLoading = false;
                          setState(() {});
                        }
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
                  },
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.white, backgroundColor: const Color(0xFF00256B),
                      minimumSize: const Size.fromHeight(56.0)),
                  child: const Text(
                    "검색하기",
                    style: TextStyle(fontSize: 18),
                  ),
                ),

              ],
            )),
      ],
    );
  }
}