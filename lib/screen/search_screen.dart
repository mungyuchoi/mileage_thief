import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:mileage_thief/helper/AdHelper.dart';
import 'package:mileage_thief/screen/detail/search_detail__round_screen.dart';
import 'package:mileage_thief/screen/detail/search_detail_one_way_screen.dart';
import '../custom/CustomDropdownButton2.dart';
import '../model/search_model.dart';
import 'package:share/share.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            '마일리지 도둑',
            style: const TextStyle(color: Colors.black),
          ),
          leading: Image.asset(
            'asset/img/airplane.png',
            scale: 2,
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
                Share.share(description);
              },
            ),
            IconButton(
              icon: const Icon(Icons.chat, color: Colors.black54),
              onPressed: () {
                _launchOpenChat();
              },
            )
          ],
        ),
        body: FutureBuilder<InitializationStatus>(
          future: _initGoogleMobileAds(),
          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
            return SingleChildScrollView(
              child: AirportScreen(key: airportScreenKey),
            );
          },
        ));
  }

  Future<InitializationStatus> _initGoogleMobileAds() {
    return MobileAds.instance.initialize();
  }

  void _launchOpenChat() async {
    const url = 'https://open.kakao.com/o/grMdcJ7e';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
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
  final List<String> dateItems = [
    "전체",
    "1박2일",
    "2박3일",
    "3박4일",
    "4박5일",
    "5박6일",
    "6박7일",
    "7박8일",
    "8박9일",
    "9박10일",
    "10박11일",
    "11박12일",
    "12박13일",
    "13박14일",
    "14박15일",
    "15박16일",
    "16박17일",
    "17박18일",
    "18박19일",
    "19박20일",
    "20박21일",
    "21박22일",
    "22박23일",
    "23박24일",
    "24박25일",
    "25박26일",
    "26박27일",
    "27박28일",
    "28박29일",
    "29박30일",
  ];
  final List<String> classItems = ["이코노미", "비즈니스", "이코노미+비즈니스"];
  List<String> airportItems = [];
  String? dateSelectedValue;
  String? classSelectedValue = "이코노미";
  String? departureSelectedValue = "서울|인천-ICN";
  String? arrivalSelectedValue;
  late BannerAd _banner;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  final DatabaseReference _classReference =
      FirebaseDatabase.instance.ref("CLASS");
  final DatabaseReference _countryReference =
      FirebaseDatabase.instance.ref("COUNTRY");

  int _counter = 3;

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
    // _loadFullScreenAd();
  }

  _loadFullScreenAd() {
    InterstitialAd.load(
      adUnitId: AdHelper.frontBannerAdUnitId,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          this._interstitialAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
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
    _classReference.once().then((event) {
      final snapshot = event.snapshot;
      Map<dynamic, dynamic>? values = snapshot.value as Map<dynamic, dynamic>?;
      if (values != null) {
        classItems.clear();
        values.forEach((key, value) {
          classItems.add(key);
        });
        classItems.sort();
        classItems.remove("이코노미");
        classItems.insert(0, "이코노미");
        setState(() {});
      }
    });
  }

  void showFrontAd() {
    _loadFullScreenAd();
    // print("showFrontAd _:$_interstitialAd");
    // _interstitialAd?.show();
    // _incrementCounter(2);
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
        msg: "우측 상단위 \$ 버튼을 선택하여 포인트를 쌓으세요!",
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
            color: Colors.grey,
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
                    color: Colors.black38,
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
                const Padding(padding: EdgeInsets.all(8)),
                Row(
                  children: [
                    Expanded(
                      child: CustomDropdownButton2(
                        hint: '어디서 가나요?',
                        dropdownWidth: 180,
                        dropdownItems: airportItems,
                        hintAlignment: Alignment.center,
                        value: departureSelectedValue,
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
                      child: CustomDropdownButton2(
                        hint: '어디로 가나요?',
                        dropdownWidth: 180,
                        hintAlignment: Alignment.center,
                        dropdownItems: airportItems,
                        value: arrivalSelectedValue,
                        onChanged: (value) {
                          setState(() {
                            arrivalSelectedValue = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.all(8)),
                const Divider(
                  color: Colors.black,
                  thickness: 2,
                ),
                const Padding(padding: EdgeInsets.all(8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Text('클래스'),
                        const Padding(padding: EdgeInsets.all(4)),
                        CustomDropdownButton2(
                          buttonWidth: 140,
                          dropdownWidth: 140,
                          valueAlignment: Alignment.center,
                          hint: '비즈니스, 퍼스트',
                          dropdownItems: classItems,
                          value: classSelectedValue,
                          onChanged: (value) {
                            setState(() {
                              classSelectedValue = value;
                            });
                          },
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('검색박수'),
                        const Padding(padding: EdgeInsets.all(4)),
                        CustomDropdownButton2(
                          buttonWidth: 100,
                          dropdownWidth: 100,
                          valueAlignment: Alignment.center,
                          hint: '전체',
                          dropdownItems: dateItems,
                          value: dateSelectedValue,
                          onChanged: (value) {
                            setState(() {
                              dateSelectedValue = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.all(8)),
                const Divider(
                  color: Colors.black,
                  thickness: 2,
                ),
                const Padding(padding: EdgeInsets.all(8)),
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
                      onPressed: () {
                        showFrontAd();
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
                ElevatedButton(
                  onPressed: () {
                    bool isUseCounter = useCounter();
                    print("onPressed search isUserCounter:$isUseCounter");
                    if (!isUseCounter) return;
                    if (xAlign == -1.0) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SearchDetailScreen(
                                  SearchModel(
                                      isRoundTrip:
                                          xAlign == -1.0 ? true : false,
                                      departureAirport: departureSelectedValue,
                                      arrivalAirport: arrivalSelectedValue,
                                      seatClass: classSelectedValue,
                                      searchDate: dateSelectedValue))));
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
                                      seatClass: classSelectedValue,
                                      searchDate: dateSelectedValue))));
                    }
                  },
                  style: TextButton.styleFrom(
                      primary: Colors.white,
                      backgroundColor: Colors.black54,
                      minimumSize: const Size.fromHeight(56.0)),
                  child: const Text(
                    "검색하기",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                Container(
                    margin: const EdgeInsets.only(top: 10),
                    height: 50,
                    child: AdWidget(
                      ad: _banner,
                    ))
              ],
            )),
      ],
    );
  }
}
