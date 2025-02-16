import 'package:flutter/material.dart';

import '../shared_pref/shared.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      bool loggedIn =
          SharedPrefController().getValueFor<bool>(Key: PreKey.loggedIn.name) ??
              false;
      String rout = loggedIn ? '/barcode_scanner_page' :'/login_screen';
      Navigator.pushReplacementNamed(context, rout);
    });
  }

  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        alignment: AlignmentDirectional.center,
        decoration: BoxDecoration(
          image:DecorationImage(
            image: AssetImage('assets/IMG-20230719-WA0010.jpg'),
               fit: BoxFit.cover
          ),
            gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
              Colors.pink.shade200,
              Colors.blueAccent.shade200,
            ])),
      ),
    );
  }
}
