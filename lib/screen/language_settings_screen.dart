import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../l10n/app_locale.dart';
import '../services/language_service.dart';

/// 언어 설정 화면 — 한국어(기본) / English.
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(L10n.t('language.title'),
            style: const TextStyle(color: Colors.black)),
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: appLanguage,
        builder: (context, lang, _) {
          Widget option(String code, String label) {
            return Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: RadioListTile<String>(
                value: code,
                groupValue: lang,
                activeColor: Colors.black,
                onChanged: (value) async {
                  if (value == null || value == lang) return;
                  await LanguageService.setLanguage(value);
                  Fluttertoast.showToast(msg: L10n.t('language.changed'));
                },
                title: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            );
          }

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Text(
                  L10n.t('language.subtitle'),
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              option('ko', L10n.t('language.korean')),
              option('en', L10n.t('language.english')),
            ],
          );
        },
      ),
    );
  }
}
