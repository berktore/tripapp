import 'package:flutter/material.dart';

class DestinationCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  const DestinationCard({
    super.key,
    required this.title,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Stack(
      children: [
        Image.network(
          imageUrl,
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ),
      ],
    ),
  );
}
