import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:linkedin_auth/linkedin_auth.dart';

void main() => runApp(MyApp());

/// This is a client side token collection example, for server side, you need
/// to implement a web server capable of doing the secret exchange and returning the access token
/// For more info, please visit:
/// https://docs.microsoft.com/en-us/linkedin/shared/authentication/authorization-code-flow?context=linkedin/context#step-3-exchange-authorization-code-for-an-access-token
class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinkedIn Auth Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: _HomeWidget(),
    );
  }
}

class _HomeWidget extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("LinkedIn Login Example"),
      ),
      body: Center(
        child: MaterialButton(
          color: Colors.blue,
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => Scaffold(
                      appBar: AppBar(
                        leading: CloseButton(),
                      ),
                      body: LinkedInLoginView(
                        clientId: "what_an_id",
                        redirectUrl: "https://www.example.com",
                        onError: (String error) {
                          print(error);
                        },
                        bypassServerCheck: true,
                        clientSecret: "what_a_secret",
                        onTokenCapture: (token) {
                          print(token);
                          Navigator.pop(context, token);
                        },
                        onServerResponse: (res) {
                          var parsed = json.decode(res.body);
                          return AccessToken(
                              parsed["token"], parsed["expiry"]);
                        },
                      ))),
            );
          },
          child: Text("Signup/Login", style: TextStyle(color:Colors.white),),
        ),
      ),
    );
  }

}
