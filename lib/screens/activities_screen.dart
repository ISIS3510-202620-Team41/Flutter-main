import 'package:flutter/material.dart';

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Text('Activities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
