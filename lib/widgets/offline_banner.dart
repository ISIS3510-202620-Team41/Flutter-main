import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF1D2),
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 9,
          ),
          child: const Row(
            children: [
              Icon(
                Icons.wifi_off,
                size: 17,
                color: Color(0xFF765B22),
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Modo sin conexión — Sincronizando al reconectar',
                  style: TextStyle(
                    color: Color(0xFF765B22),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
