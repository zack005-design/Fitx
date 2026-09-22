import 'package:flutter/material.dart';

const referenceBackground = Color(0xfff2f2f7);
const referenceBlue = Color(0xff0058bc);
const referenceGreen = Color(0xff34c759);
const referenceMuted = Color(0xff74747c);

ThemeData referenceTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: referenceBackground,
      colorScheme: ColorScheme.fromSeed(
          seedColor: referenceBlue,
          brightness: Brightness.light,
          surface: Colors.white),
      fontFamily: 'Inter',
      textTheme: ThemeData.light().textTheme.apply(
          fontFamily: 'Inter',
          bodyColor: const Color(0xff1c1c1e),
          displayColor: const Color(0xff1c1c1e)),
      dividerColor: const Color(0xffe5e5ea),
    );

class ReferenceCard extends StatelessWidget {
  const ReferenceCard({super.key, required this.child, this.padding = 20});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffe5e5ea)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x08000000), blurRadius: 3, offset: Offset(0, 2))
            ]),
        child: Material(type: MaterialType.transparency, child: child),
      );
}

const referenceMetric = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -.6,
    fontFeatures: [FontFeature.tabularFigures()]);
const referenceCaption =
    TextStyle(fontSize: 11, color: referenceMuted, letterSpacing: .6);
