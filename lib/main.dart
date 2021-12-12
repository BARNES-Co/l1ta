import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:l1ta/map_demo.dart';

import 'package:speech_to_text/speech_to_text.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Container(
          child: Scaffold(drawer: SideDrawer(), body: MapDemoScreen())),
    );
  }
}

class SideDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Drawer(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 100,
              child: DrawerHeader(
                padding: EdgeInsets.all(0),
                child: Center(
                    heightFactor: 50,
                    child: Icon(Icons.card_giftcard,
                        size: 50, color: Colors.orange)),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.home,
                color: Colors.white,
              ),
              title: Text(
                'Home',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => {},
            ),
            ListTile(
              leading: Icon(
                Icons.shopping_cart,
                color: Colors.white,
              ),
              title: Text(
                'Cart',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => {Navigator.of(context).pop()},
            ),
            ListTile(
              leading: Icon(
                Icons.border_color,
                color: Colors.white,
              ),
              title: Text(
                'Feedback',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => {Navigator.of(context).pop()},
            ),
            ListTile(
              leading: Icon(
                Icons.exit_to_app,
                color: Colors.white,
              ),
              title: Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => {Navigator.of(context).pop()},
            ),
          ],
        ),
      ),
    );
  }
}
