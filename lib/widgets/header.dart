import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class Header extends StatelessWidget {
  const Header({super.key, this.onAdd, this.showAdd = true});

  final VoidCallback? onAdd;
  final bool showAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Llamalla',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Spacer(),
        if (showAdd)
          Material(
            color: AppColors.rosewood,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onAdd,
              child: const SizedBox(
                width: 30,
                height: 30,
                child: Icon(Icons.add, size: 18, color: AppColors.white),
              ),
            ),
          ),
      ],
    );
  }
}
