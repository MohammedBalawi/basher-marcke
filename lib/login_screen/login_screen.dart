
import 'package:bashar_market/shared_pref/context-extenssion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


import 'package:shared_preferences/shared_preferences.dart';



class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  bool _obscureText = true;

  late TextEditingController _emailTextController;
  late TextEditingController _passwordTextController;


  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _emailTextController = TextEditingController();
    _passwordTextController = TextEditingController();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _emailTextController.dispose();
    _passwordTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('login',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black),
        ),
      ),
      body:Stack(
          children: [
      Positioned.fill(
      child: Image.asset(
          'assets/IMG-20230719-WA0011.jpg', fit: BoxFit.cover),
    ),
    Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'login New...!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.black,
              ),
            ),
            const Text(
              'login To Start Use',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailTextController,
              onTap: () => print('Tapped'),
              onChanged: (String value) => print('Value: $value'),
              textInputAction: TextInputAction.send,
              onSubmitted: (String value) => print('Submitted: $value'),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  maxHeight: _emailError == null ? 50 : 70,
                ),
                hintText:'email',
                hintMaxLines: 1,
                prefixIcon: const Icon(Icons.email),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Colors.grey,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Colors.green,
                    width: 1,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                errorText: _emailError,
                errorMaxLines: 1,
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    width: 1,
                    color: Colors.red.shade300,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    width: 1,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordTextController,
              keyboardType: TextInputType.text,

              obscureText: _obscureText,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.zero,
                constraints:
                BoxConstraints(maxHeight: _passwordError == null ? 50 : 70),
                hintText: 'password',
                hintMaxLines: 1,
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscureText = !_obscureText);
                  },
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    width: 1,
                    color: Colors.grey,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    width: 1,
                    color: Colors.blue,
                  ),
                ),
                errorText: _passwordError,
                errorMaxLines: 1,
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    width: 1,
                    color: Colors.red.shade300,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    width: 1,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () async => await _performLogin(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child:  const Text('login',style: TextStyle(
                  color: Colors.white
                ),),
              ),
            ),
          ],
        ),
      ),
         ] ),
    );
  }

  Future<void> _performLogin() async {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    if (_checkData()) {
      if (_emailTextController.text == 'moudybalawi@gmail.com' &&
          _passwordTextController.text == '123123') {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setBool('loggedIn', true);
        Navigator.pushReplacementNamed(context,'/barcode_scanner_page');
      } else {
        context.showMessage(message: 'Invalid email or password', error: true);
      }
    }
  }


  bool _checkData() {
    _controlErrorValue();
    if (_emailTextController.text.isNotEmpty &&
        _passwordTextController.text.isNotEmpty) {
      return true;
    }
    context.showMessage(message: 'Error, enter required data!', error: true);
    return false;
  }

  //
  void _controlErrorValue() {
    setState(() {
      _emailError =
      _emailTextController.text.isEmpty ? 'Enter email address' : null;
      _passwordError =
      _passwordTextController.text.isEmpty ? 'Enter password' : null;
    });
  }

  //
  // void _login() async {
  //   ProcessResponse processResponse = await UserDbController().login(
  //       email: _emailTextController.text,
  //       password: _passwordTextController.text);
  //   if(processResponse.success){
  //     Navigator.pushReplacementNamed(context as BuildContext, '/home_screen');
  //   }
  //   context.showMessage(
  //       message: processResponse.message, error: !processResponse.success);
  // }

}


