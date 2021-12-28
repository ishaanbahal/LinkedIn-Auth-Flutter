import 'package:flutter/material.dart';
import 'package:linkedin_auth/src/models/models.dart';
import 'package:linkedin_auth/src/service/linkedin_service.dart';

import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

/// Renders a [WebView] without a scaffold. One must provide a base view to render
/// the view. You can use a full page route and render it or use an Dialog. This view
/// will not render without a scaffold parent.
///
/// Programmatic Refresh tokens are available to only select partners to LinkedIn, so have been excluded from this library.
class LinkedInLoginView extends StatefulWidget {
  /// Redirect Url provided to linkedIn developer console
  final String redirectUrl;

  /// Client ID from developer dashboard
  final String clientId;

  /// OPTIONAL: Client secret from developer dashboard, avoid using this unless app is not distributed publicly
  final String clientSecret;

  /// Set to true if you want to bypass server response method and provide client secret from device.
  /// UNSAFE for distributing apps over stores.
  final bool bypassServerCheck;

  /// Custom callback for onError method, please provide one to get errors and do actions on them.
  final Function(String) onError;

  /// Success callback when token is captured, from this method, normally you would close the
  /// scaffold by calling [Navigation.pop] and use [AccessToken] to store in secure storage.
  final Function(AccessToken) onTokenCapture;

  /// This method is required to read the server response if the client secret is hosted on your server.
  /// Any calls to redirect URI will be bypassed from the [WebView] and called directly and the
  /// [http.Response] will be given to the user to fetch token and expiry from it.
  ///
  /// One must implement a server method that sends out data that your custom method can read
  /// and parse these two values from it.
  ///
  /// The server must implement the third leg in the 3-legged auth, for more info, read:
  /// https://docs.microsoft.com/en-us/linkedin/shared/authentication/authorization-code-flow?context=linkedin/context#step-3-exchange-authorization-code-for-an-access-token
  final AccessToken Function(http.Response) onServerResponse;

  /// Scopes to get access for, default scope would be [LinkedInScope.LITE_PROFILE] & [LinkedInScope.EMAIL_ADDRESS]
  /// Optional field, can be ignored for default behaviour.
  final List<LinkedInScope>? scopes;

  LinkedInLoginView(
      {required this.redirectUrl,
      required this.clientId,
      required this.onError,
      this.clientSecret = "",
      this.bypassServerCheck = false,
     required this.onTokenCapture,
     required this.onServerResponse,
      this.scopes});

  _LinkedInLoginViewState createState() => _LinkedInLoginViewState();
}

class _LinkedInLoginViewState extends State<LinkedInLoginView> {
  static const _LINKEDIN_CODE = "code";
  static const _LINKEDIN_STATE = "state";
  static const _LINKEDIN_ERROR = "error";
  static const _LINKEDIN_ERROR_DESC = "error_description";
  late LinkedInRequest _request;

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    final cookieManager = CookieManager();
    cookieManager.clearCookies();
  }
  
  @override
  void initState() {
    super.initState();
    List<LinkedInScope> scopelist =  [LinkedInScope.EMAIL_ADDRESS, LinkedInScope.LITE_PROFILE];
    _request = LinkedInService.getLinkedInRequest(
      clientId: widget.clientId,
      redirectUri: widget.redirectUrl,
      scopes: widget.scopes ?? scopelist
    );
  }

  @override
  Widget build(BuildContext context) {
    return WebView(
      initialUrl: _request.url,
      javascriptMode: JavascriptMode.unrestricted,
      navigationDelegate: _navDelegate,
    );
  }

  /// Handles the navigation delegation for the [WebView]. If redirectUrl is found
  /// in the URL, then either locally client secret is to be provided depending on the
  /// [widget.bypassServerCheck] flag or a call is made separately to the server and parsed
  /// by the custom [widget.onServerResponse] method.
  ///
  /// On any error, navigation is prevented and error is returned in [widget.onError]
  ///
  /// On successful token capture, [widget.onTokenCapture] gets the data, from where,
  /// one must close the WebView.
  NavigationDecision _navDelegate(NavigationRequest req) {
    if (req.url.contains(widget.redirectUrl)) {
      Uri uri = Uri.parse(req.url);
      Map<String, String> params = uri.queryParameters;
      String error = _parseError(params);
      if (error.isNotEmpty) {
        widget.onError(error);
        return NavigationDecision.prevent;
      }
      if (params.containsKey(_LINKEDIN_STATE) &&
          !_request.verifyState(params[_LINKEDIN_STATE]!)) {
        widget.onError("State match failed, possible CSRF issue");
        return NavigationDecision.prevent;
      }
      if (params.containsKey(_LINKEDIN_CODE) && widget.bypassServerCheck) {
        _getToken(params[_LINKEDIN_CODE]!);
      } else {
        _getServerData(req.url);
        return NavigationDecision.prevent;
      }
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _getServerData(String url) async {
    var res = await http.get(Uri.dataFromString(url));
    var token = widget.onServerResponse(res);
    if (widget.onTokenCapture != null) {
      widget.onTokenCapture(token);
    } else {
      Navigator.pop(context, token);
    }
  }

  Future<void> _getToken(String code) async {
    try {
      var token = await LinkedInService.generateToken(
          clientId: widget.clientId,
          clientSecret: widget.clientSecret,
          code: code,
          redirectUri: widget.redirectUrl);
      if (widget.onTokenCapture != null) {
        widget.onTokenCapture(token);
      } else {
        Navigator.pop(context, token);
      }
    } catch (e) {
      widget.onError(e.toString());
    }
  }

  String _parseError(Map<String, String> params) {
    if (params.containsKey(_LINKEDIN_ERROR)) {
      return params[_LINKEDIN_ERROR_DESC]!;
    }
    return "";
  }
}
