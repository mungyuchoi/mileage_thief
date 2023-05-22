class Notice {
  Notice({required this.date, required this.title, required this.description});

  String date;
  String title;
  String description;
}

class FAQ {
  FAQ(
      {required this.requestTitle,
      required this.requestDescription,
      required this.responseTitle,
      required this.responseDescription});

  String requestTitle;
  String requestDescription;
  String responseTitle;
  String responseDescription;
}
