import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../helper/AdHelper.dart';
import '../utils/ad_removal_utils.dart';

class AppBannerAd extends StatefulWidget {
  final String? adUnitId;
  final EdgeInsetsGeometry padding;
  final bool reserveSpace;

  const AppBannerAd({
    super.key,
    this.adUnitId,
    this.padding = EdgeInsets.zero,
    this.reserveSpace = true,
  });

  @override
  State<AppBannerAd> createState() => _AppBannerAdState();
}

class _AppBannerAdState extends State<AppBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _initAd();
  }

  Future<void> _initAd() async {
    final shouldHide = await AdRemovalUtils.isAdRemovalActive();
    if (!mounted) return;
    if (shouldHide) {
      setState(() => _hidden = true);
      return;
    }

    late final String adUnitId;
    try {
      adUnitId = widget.adUnitId ?? AdHelper.postDetailProfileBannerAdUnitId;
    } catch (_) {
      if (mounted) setState(() => _hidden = true);
      return;
    }

    final ad = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
        },
      ),
    );

    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    if (!_loaded || _ad == null) {
      return widget.reserveSpace
          ? Padding(
              padding: widget.padding,
              child: const SizedBox(height: 50),
            )
          : const SizedBox.shrink();
    }

    return Padding(
      padding: widget.padding,
      child: SizedBox(
        width: double.infinity,
        child: Center(
          child: SizedBox(
            width: _ad!.size.width.toDouble(),
            height: _ad!.size.height.toDouble(),
            child: AdWidget(ad: _ad!),
          ),
        ),
      ),
    );
  }
}
