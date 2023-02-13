import 'package:flutter/material.dart';
import 'package:mileage_thief/model/search_model.dart';

class SearchDetailScreen extends StatelessWidget {
  final SearchModel searchModel;
  SearchDetailScreen(this.searchModel);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black12,
        body: Center(
            child: ElevatedButton(
          child: const Text('돌아가기'),
          onPressed: () {
            print(searchModel.isRoundTrip);
            print(searchModel.departureAirport);
            print(searchModel.arrivalAirport);
            print(searchModel.seatClass);
            print(searchModel.searchDate);

            Navigator.pop(context);
          },
        )));
  }
}
