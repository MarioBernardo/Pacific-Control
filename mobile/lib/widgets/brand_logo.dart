import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 96});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/pacific_security_force_logo.png',
      height: height,
      fit: BoxFit.contain,
    );
  }
}
