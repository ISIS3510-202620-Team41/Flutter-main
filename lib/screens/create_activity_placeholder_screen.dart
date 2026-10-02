import 'package:flutter/material.dart';

class CreateActivityPlaceholderScreen extends StatelessWidget {
  const CreateActivityPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Text('CreateActivity Placeholder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
