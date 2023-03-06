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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text(
            '마일리지 도둑',
            style: TextStyle(color: Colors.black),
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
                  appLink = 'https://apps.apple.com/app/myapp/id12345678';
                }
                String description = "마일리지 항공 앱을 공유해보세요! $appLink";
                Share.share(description);
              },
            ),
            IconButton(
              icon:Icon(Icons.chat, color: Colors.black54),
              onPressed: () {
                _launchOpenChat();
              },
            )
          ],
        ),
        body: FutureBuilder<InitializationStatus>(
          future: _initGoogleMobileAds(),
          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
            return const SingleChildScrollView(
              child: AirportScreen(),
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
  const AirportScreen({Key? key}) : super(key: key);

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
  final List<String> classItems = ["전체"];
  List<String> airportItems = [];
  String? dateSelectedValue;
  String? classSelectedValue;
  String? departureSelectedValue;
  String? arrivalSelectedValue;
  late BannerAd _banner;
  RewardedAd? _rewardedAd;
  final DatabaseReference _countryReference =
      FirebaseDatabase.instance.ref("COUNTRY");

  @override
  void initState() {
    super.initState();
    _loadCountryFirebase();
    xAlign = loginAlign;
    loginColor = selectedColor;
    signInColor = normalColor;
    _banner = BannerAd(
      listener: BannerAdListener(
        onAdFailedToLoad: (Ad ad, LoadAdError error) {},
        onAdLoaded: (_) {},
      ),
      size: AdSize.banner,
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
    )..load();
    _loadRewardedAd();
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
        },
      ),
    );
  }

  void _loadCountryFirebase() {
    print("loadCountryFirebase!!!!");
    _countryReference.once().then((event) {
      final snapshot = event.snapshot;
      Map<dynamic, dynamic>? values = snapshot.value as Map<dynamic, dynamic>?;
      if(values != null){
        airportItems.clear();
        values.forEach((key, value) {
          airportItems.add(key);
        });
        setState(() {
        });
      }
    });
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
                      '왕복',
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
                      '편도',
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
                    const Icon(
                      Icons.double_arrow_rounded,
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
                          buttonWidth: 100,
                          dropdownWidth: 110,
                          valueAlignment: Alignment.center,
                          hint: '전체',
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
                ElevatedButton(
                  onPressed: () {
                    print("pressed MQ!! _rewardedAd: $_rewardedAd");
                    _rewardedAd?.show(onUserEarnedReward: (_, reward) {
                      if (xAlign == -1.0) {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SearchDetailRoundScreen(
                                    SearchModel(
                                        isRoundTrip:
                                            xAlign == -1.0 ? true : false,
                                        departureAirport:
                                            departureSelectedValue,
                                        arrivalAirport: arrivalSelectedValue,
                                        seatClass: classSelectedValue,
                                        searchDate: dateSelectedValue))));
                      } else {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SearchDetailScreen(
                                    SearchModel(
                                        isRoundTrip:
                                            xAlign == -1.0 ? true : false,
                                        departureAirport:
                                            departureSelectedValue,
                                        arrivalAirport: arrivalSelectedValue,
                                        seatClass: classSelectedValue,
                                        searchDate: dateSelectedValue))));
                      }
                    });
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
