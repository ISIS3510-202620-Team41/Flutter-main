import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FBFF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 30, 40, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BrandHeader(),
              const SizedBox(height: 36),
              const Text(
                'Qué bueno verte de\nnuevo',
                style: TextStyle(
                  fontSize: 26,
                  height: 1.16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Entra para descubrir qué puedes hacer en tu\npróxima ventana libre.',
                style: TextStyle(
                  color: Color(0xFF5D6870),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 34),
              const _FieldLabel('Correo'),
              const SizedBox(height: 8),
              const TextField(
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'nombre@universidad.edu',
                  hintStyle: TextStyle(color: Color(0xFF92999D), fontSize: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Color(0xFFE5EDF1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppColors.blue),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Contraseña'),
              const SizedBox(height: 8),
              TextField(
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Tu contraseña',
                  hintStyle: const TextStyle(
                    color: Color(0xFF92999D),
                    fontSize: 14,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Color(0xFFE5EDF1)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppColors.blue),
                  ),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 19,
                      color: const Color(0xFF68747B),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosewood,
                    disabledBackgroundColor: AppColors.rosewood,
                    disabledForegroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Iniciar sesión',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 27),
              const _DividerLabel(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const _GoogleMark(),
                  label: const Text(
                    'Continuar con Google',
                    style: TextStyle(
                      color: AppColors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    disabledForegroundColor: AppColors.black,
                    side: const BorderSide(color: Color(0xFFE5EDF1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.fingerprint,
                    color: AppColors.blue,
                    size: 20,
                  ),
                  label: const Text(
                    'Ingresar con biometría',
                    style: TextStyle(
                      color: AppColors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5FBFF),
                    disabledForegroundColor: AppColors.black,
                    side: const BorderSide(color: AppColors.blue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    const Text(
                      '¿Aún no tienes perfil? ',
                      style: TextStyle(color: Color(0xFF5D6870), fontSize: 12),
                    ),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.rosewood,
                      ),
                      child: const Text(
                        'Crear una cuenta',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.access_time,
            color: AppColors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actividad ya',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 2),
            Text(
              'Tu tiempo entre clases',
              style: TextStyle(color: Color(0xFF657078), fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE2E9ED))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'o continúa con',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE2E9ED))),
      ],
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
