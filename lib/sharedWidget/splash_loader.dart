import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';


class CircularLoaderImage extends StatelessWidget {
  const CircularLoaderImage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SvgPicture.asset(
              'assets/icon/MYNT App Logo_v2.svg',
              width: 80,
              height: 80,
            ),
          ),
          const Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 90,
                height: 90,
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
