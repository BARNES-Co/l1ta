import 'package:flutter/material.dart';
import 'package:adobe_xd/pinned.dart';

class Web19201 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff85b2e8),
      body: Stack(
        children: <Widget>[
          Pinned.fromPins(
            Pin(size: 618.0, middle: 0.5338),
            Pin(size: 304.0, middle: 0.4588),
            child: Container(
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.all(Radius.elliptical(9999.0, 9999.0)),
                color: const Color(0xffffffff),
                border: Border.all(width: 1.0, color: const Color(0xff707070)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
