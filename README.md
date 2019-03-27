
# LinkedIn Auth (Unofficial)

Flutter auth for LinkedIn using V2 APIs and OAuth 2.0

## Getting Started

### Registering as a developer on LinkedIn
- To get started, first you must create an account on: https://www.linkedin.com/developers/login
- Create an app, and complete necessary steps
- Setup redirect url on `Auth Tab -> OAuth 2.0 Settings -> Redirect URLs`
- Collect `clientId` and `clientSecret` from `Auth Tab -> Application Credentials`

### Authenticating with LinkedIn in Flutter app
> Before using auth, there are two methods to complete the third step for 3-legged auth. It's important to know that if you ship a client secret with your app, you must make sure that its either kept very secure or the app is not shipped for general public. One method just sends the client secret from the app itself, and the other method expects you to have a service that does it for you and provide a method to parse that response.

#### Server side authentication [RECOMMENDED]
For server side authentication, you must have a server that when called with query params, code and state, returns an access token by completing the third leg in the 3-legged auth explained here: https://docs.microsoft.com/en-us/linkedin/shared/authentication/authorization-code-flow?context=linkedin/context#step-3-exchange-authorization-code-for-an-access-token

Once these are setup, the code usually looks like this:
```
FlatButton(
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
                onServerResponse: (res){
                  var parsed = json.decode(res.body);
                  return AccessToken(parsed["token"], parsed["expiry"]),
                },
                onTokenCapture: (token) {
                  this.token = token.token;
                  Navigator.pop(context, token);
                },
              ))),
    );
    print("Ended, must've gotten result here: ${this.token}");
  },
  child: Text("Signup/Login"),
),
```

After capturing token, one can simply use it to fetch profile, email address and display image. 


#### Client side authentication [UNSAFE]
For client side authentication, you must ship the client secret with the app itself. You can do the auth simply as follows:

```
FlatButton(
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
                  this.token = token.token;
                  Navigator.pop(context, token);
                },
                onServerResponse: (res){
                  var parsed = json.decode(res.body);
                  return AccessToken(parsed["token"], parsed["expiry"]),
                },
              ))),
    );
    print("Ended, must've gotten result here: ${this.token}");
  },
  child: Text("Signup/Login"),
),
```

> After the end on either of the two methods, you get an AccessToken which you can use to fetch data from LinkedIn. You can also provide multiple scopes manually to `LinkedInLoginView`. Normally two scopes are requested `r_liteprofile` and `r_emailaddress`. Basic profile is shown in access but is non accessible by developers without special access from LinkedIn.

### Getting data from LinkedIn: Profile, Email Address, Display image

#### Getting the lite profile & display image
```
FlatButton(
  onPressed: () async {
    try{
      var liteProfile =await LinkedInService.getLiteProfile(token);
      print(liteProfile);
      var profileImage = await liteProfile.profileImage.getDisplayImageUrl(token);
      print(profileImage);
    } on LinkedInException catch(e){
      print(e.cause);
    }
  },
  child: Text("Get Lite Profile"),
),
```
> Note: Display image is only 100X100 in resolution. Original image requires special access from linkedIn.

#### Getting email address
```
FlatButton(
  onPressed: () async {
    var email = await LinkedInService.getEmailAddress(token);
    print(email);
  },
  child: Text("Get Email address"),
),
```

#### Get Basic Profile (Special permission required)
```
FlatButton(
  onPressed: () async {
    try{
      var basicProfile =await LinkedInService.getBasicProfile(token);
      print(basicProfile);
      var profileImage = await basicProfile.profileImage.getDisplayImageUrl(token);
      print(profileImage);
    } on LinkedInException catch(e){
      print(e.cause);
    }
  },
  child: Text("Get Basic Profile"),
),
```

### Refreshing Token
Programmatic refresh of tokens is only available to select developers, hence not included in this package.
For normal refresh of token, one must check expiry of the access token and re-run the Auth flow before it expires.
If the token is not expired, it will skip the login view and directly give you a new token. If it has expired, the login
page will appear and user has to login again.

Read more: https://docs.microsoft.com/en-us/linkedin/shared/authentication/authorization-code-flow?context=linkedin/context#step-5-refresh-access-token
