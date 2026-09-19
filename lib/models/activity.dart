class Activity {
  const Activity({
    required this.category,
    required this.name,
    required this.distance,
    required this.duration,
    required this.price,
    required this.people,
    required this.imageUrl,
    this.fitsWindow = true,
  });

  final String category;
  final String name;
  final String distance;
  final String duration;
  final String price;
  final String people;
  final String imageUrl;
  final bool fitsWindow;
}

class FriendStatus {
  const FriendStatus({
    required this.initials,
    required this.name,
    required this.status,
    this.statusInMinutes = false,
  });

  final String initials;
  final String name;
  final String status;
  final bool statusInMinutes;
}
