class ItineraryStop {
  final String time;
  final String title;
  final String description;
  final String category;
  final double? latitude;
  final double? longitude;
  final String? osmId;

  const ItineraryStop({
    required this.time,
    required this.title,
    required this.description,
    required this.category,
    this.latitude,
    this.longitude,
    this.osmId,
  });

  Map<String, dynamic> toJson() => {
    'time': time,
    'title': title,
    'description': description,
    'category': category,
    'latitude': latitude,
    'longitude': longitude,
    'osmId': osmId,
  };

  factory ItineraryStop.fromJson(Map<String, dynamic> json) => ItineraryStop(
    time: json['time'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    category: json['category'] as String? ?? 'Gezi',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    osmId: json['osmId'] as String?,
  );
}

class ItineraryDay {
  final int dayNumber;
  final String title;
  final List<ItineraryStop> stops;

  const ItineraryDay({
    required this.dayNumber,
    required this.title,
    required this.stops,
  });

  Map<String, dynamic> toJson() => {
    'dayNumber': dayNumber,
    'title': title,
    'stops': stops.map((stop) => stop.toJson()).toList(),
  };

  factory ItineraryDay.fromJson(Map<String, dynamic> json) => ItineraryDay(
    dayNumber: (json['dayNumber'] as num?)?.toInt() ?? 1,
    title: json['title'] as String? ?? 'Gezi günü',
    stops: (json['stops'] as List<dynamic>? ?? [])
        .map(
          (item) =>
              ItineraryStop.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );
}

class TripPlan {
  final String id;
  final String destination;
  final String? imageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final String travelers;
  final String budget;
  final List<String> travelStyles;
  final DateTime createdAt;
  final List<ItineraryDay> itinerary;

  const TripPlan({
    required this.id,
    required this.destination,
    this.imageUrl,
    required this.startDate,
    required this.endDate,
    required this.travelers,
    required this.budget,
    required this.travelStyles,
    required this.createdAt,
    this.itinerary = const [],
  });

  int get duration => endDate.difference(startDate).inDays + 1;

  Map<String, dynamic> toJson() => {
    'id': id,
    'destination': destination,
    'imageUrl': imageUrl,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'travelers': travelers,
    'budget': budget,
    'travelStyles': travelStyles,
    'createdAt': createdAt.toIso8601String(),
    'itinerary': itinerary.map((day) => day.toJson()).toList(),
  };

  factory TripPlan.fromJson(Map<String, dynamic> json) {
    final rawItinerary = json['itinerary'] as List<dynamic>? ?? [];
    return TripPlan(
      id: json['id'] as String,
      destination: json['destination'] as String,
      imageUrl: json['imageUrl'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      travelers: json['travelers'] as String,
      budget: json['budget'] as String,
      travelStyles: List<String>.from(json['travelStyles'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      itinerary: rawItinerary
          .map(
            (item) =>
                ItineraryDay.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}
