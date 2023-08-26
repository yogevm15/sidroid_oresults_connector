import 'dart:convert';

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import 'exceptions.dart';

class EventPreview extends StatefulWidget {
  final EventApiResponse? data;

  const EventPreview({Key? key, required this.data}) : super(key: key);

  @override
  State<EventPreview> createState() => _EventPreviewState();
}

class _EventPreviewState extends State<EventPreview> {
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data == null) {
      return const SizedBox.shrink();
    }
    return ListTile(
      title: Text(data.name),
      subtitle: Text(data.place),
      trailing:
          Text(DateFormat("dd/MM/yyyy").format(DateTime.parse(data.date))),
      leading: CountryFlag.fromCountryCode(
        data.countryCode,
        height: 38,
        width: 54,
        borderRadius: 8,
      ),
    );
  }
}

class EventApiResponse {
  final int id;
  final String name;
  final String organizer;
  final String date;
  final String timeZone;
  final String place;
  final String countryCode;
  final double? lat;
  final double? long;
  final bool isRelay;
  final bool isPublic;
  final bool isSubSec;
  final int userId;

  const EventApiResponse({
    required this.id,
    required this.name,
    required this.organizer,
    required this.date,
    required this.timeZone,
    required this.place,
    required this.countryCode,
    required this.lat,
    required this.long,
    required this.isRelay,
    required this.isPublic,
    required this.isSubSec,
    required this.userId,
  });

  factory EventApiResponse.fromJson(Map<String, dynamic> json) {
    return EventApiResponse(
      id: json['id'],
      name: json['name'],
      organizer: json["organizer"],
      date: json['date'],
      timeZone: json["timezone"],
      place: json["place"],
      countryCode: json['countryCode'],
      lat: json["lat"],
      long: json["long"],
      isRelay: json["isRelay"],
      isPublic: json["isPublic"],
      isSubSec: json["isSubsec"],
      userId: json["userId"],
    );
  }
}

class FetchEventFailed implements Exception {
  final String err;

  FetchEventFailed(this.err);
}

// returns true if the event exists and false otherwise
Future<EventApiResponse> fetchEventData(String apiKey) async {
  Uri url = Uri.https("api.oresults.eu", "events/$apiKey");
  http.Response response;
  try {
    response = await http.get(url);
  } on Exception {
    throw CouldNotReachOresults();
  }
  if (response.statusCode != 200) {
    throw EventDoesNotExists();
  }

  return EventApiResponse.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
}
