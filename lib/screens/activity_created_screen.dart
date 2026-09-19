import 'package:flutter/material.dart';

class ActivityCreatedScreen extends StatelessWidget {
  const ActivityCreatedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Text('ActivityCreated Placeholder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
