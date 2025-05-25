import 'package:flutter/material.dart';

class Event {
  final DateTime date;
  final String type; // 'economy', 'business', 'first'
  final Color color;

  Event({required this.date, required this.type, required this.color});
}