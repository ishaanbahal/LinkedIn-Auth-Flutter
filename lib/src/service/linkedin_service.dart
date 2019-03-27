import 'dart:convert';

import 'package:linkedin_auth/src/models/models.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

class LinkedInService {
  // API Endpoints and Base url
  static const _BASE_AUTH_URl = "www.linkedin.com";
  static const _LOGIN_PATH = "oauth/v2/authorization";
  static const _ACCESS_TOKEN_PATH = "oauth/v2/accessToken";

  static const _API_URL = "api.linkedin.com";
  static const _PROFILE_API_PATH = "v2/me";
  static const _EMAIL_API_PATH = "v2/emailAddress";

  // URL parameters
  static const _RESPONSE_TYPE = "response_type";
  static const _RESPONSE_TYPE_VALUE = "code";
  static const _CLIENT_ID = "client_id";
  static const _REDIRECT_URI = "redirect_uri";
  static const _STATE = "state";
  static const _SCOPE = "scope";
  static const _GRANT_TYPE = "grant_type";
  static const _GRANT_TYPE_VALUE = "authorization_code";
  static const _CLIENT_SECRET = "client_secret";
  static const _CODE = "code";

  // Scope values
  static const _SCOPE_EMAIL_ADDRESS = "r_emailaddress";
  static const _SCOPE_BASIC_PROFILE = "r_basicprofile";
  static const _SCOPE_LITE_PROFILE = "r_liteprofile";
  static const _SCOPE_SHARE_ON_LINKEDIN = "w_share";
  static const _SCOPE_COMPANY_ADMIN = "rw_company_admin";
  static const _SCOPE_MEMBER_SOCIAL = "w_member_social";

  // Response values
  static const _ACCESS_TOKEN = "access_token";
  static const _EXPIRES_IN = "expires_in";

  /// Returns [LinkedInRequest] object containing URL and state
  ///
  /// Throws a [LinkedInException] if either of the fields are empty or missing.
  /// For more info, please read https://docs.microsoft.com/en-us/linkedin/shared/authentication/authorization-code-flow
  ///
  /// Example:
  /// ```dart
  /// LinkedInService.getLinkedInRequest(
  ///      clientId: "foobar",
  ///      redirectUri: "https://www.example.com/linkedin/auth",
  ///     scopes: [LinkedInScope.EMAIL_ADDRESS, LinkedInScope.BASIC_PROFILE],
  ///    );
  /// ```
  static LinkedInRequest getLinkedInRequest({@required String clientId,
    @required String redirectUri,
    @required List<LinkedInScope> scopes}) {
    if (clientId.isEmpty) {
      throw LinkedInException("Missing client ID, cannot be left blank");
    }
    if (scopes.length == 0) {
      throw LinkedInException("At least one scope must be provided");
    }
    if (redirectUri.isEmpty) {
      throw LinkedInException(
          "Redirect URI is required and cannot be left blank");
    }

    String state = Uuid().v4();
    Uri promptUrl = Uri.https(_BASE_AUTH_URl, _LOGIN_PATH, {
      // Has to be hardcoded, please read: https://docs.microsoft.com/en-us/linkedin/shared/authentication/authorization-code-flow
      _RESPONSE_TYPE: _RESPONSE_TYPE_VALUE,
      _CLIENT_ID: clientId,
      _REDIRECT_URI: redirectUri,
      _STATE: state,
      _SCOPE: _getRequestScope(scopes),
    });

    return LinkedInRequest(state, promptUrl.toString());
  }

  /// Returns [AccessToken]
  ///
  /// Throws a [LinkedInException] if either of the fields are empty or missing.
  ///
  /// UNSAFE method, avoid using it. Exposes secret to app, and can be easily captured by attacker, safe for local testing.
  /// Sends out a post request to fetch the OAuth access token from linkedIn using the client secret
  /// and client ID.
  ///
  /// Example:
  /// ```dart
  /// LinkedInService.generateToken(
  ///        clientId: "foobar",
  ///        clientSecret: "amazeSecret#!@*",
  ///        code: "what_a_code",
  ///        redirectUri: "https://www.example.com/linkedin/auth");
  /// ```
  static Future<AccessToken> generateToken({
    @required String clientId,
    @required String clientSecret,
    @required String code,
    @required String redirectUri,
  }) async {
    Uri accessTokenUrl = Uri.https(_BASE_AUTH_URl, _ACCESS_TOKEN_PATH, {
      // Has to be hardcoded, please read: https://docs.microsoft.com/en-us/linkedin/shared/authentication/authorization-code-flow
      _GRANT_TYPE: _GRANT_TYPE_VALUE,
      _CLIENT_ID: clientId,
      _REDIRECT_URI: redirectUri,
      _CLIENT_SECRET: clientSecret,
      _CODE: code,
    });
    Map<String, String> headers = {"Content-Type": "x-www-form-urlencoded"};
    var res = await http.post(
      accessTokenUrl,
      headers: headers,
    );
    if (res.statusCode ~/ 10 != 20) {
      throw LinkedInException("Failed to fetch access token: ${res.body}");
    }
    Map<String, dynamic> parsed = json.decode(res.body);
    String token = parsed[_ACCESS_TOKEN] as String ?? "";
    int expiry = parsed[_EXPIRES_IN] as int ?? "";
    return AccessToken(token, expiry);
  }

  /// Returns [BasicProfile] from LinkedIn
  ///
  /// Throws [LinkedInException] when network call fails or returns some error
  ///
  /// Makes the call to api.linkedin.com/v2/me which fetched profile info according to Token
  /// Please make sure you call the correct profile method, as parsing may fail if you have the wrong scope.
  ///
  /// Read more:
  /// https://docs.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/sign-in-with-linkedin?context=linkedin/consumer/context#retrieving-member-profiles
  static Future<BasicProfile> getBasicProfile(String token) async {
    var parsed = await _getProfile(token);
    return BasicProfile.fromJson(parsed);
  }

  /// Returns [LiteProfile] from LinkedIn
  ///
  /// Throws [LinkedInException] when network call fails or returns some error
  ///
  /// Makes the call to api.linkedin.com/v2/me which fetched profile info according to Token
  /// Please make sure you call the correct profile method, as parsing may fail if you have the wrong scope.
  ///
  /// Read more:
  /// https://docs.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/sign-in-with-linkedin?context=linkedin/consumer/context#retrieving-member-profiles
  static Future<LiteProfile> getLiteProfile(String token) async {
    var parsed = await _getProfile(token);
    return LiteProfile.fromJson(parsed);
  }

  /// Multiple request scopes merged to form a single space separated string
  static String _getRequestScope(List<LinkedInScope> scopes) {
    List<String> scopeConvert = [];
    scopes.forEach((LinkedInScope scope) {
      switch (scope) {
        case LinkedInScope.EMAIL_ADDRESS:
          return scopeConvert.add(_SCOPE_EMAIL_ADDRESS);
        case LinkedInScope.BASIC_PROFILE:
          return scopeConvert.add(_SCOPE_BASIC_PROFILE);
        case LinkedInScope.LITE_PROFILE:
          return scopeConvert.add(_SCOPE_LITE_PROFILE);
        case LinkedInScope.SHARE_ON_LINKEDIN:
          return scopeConvert.add(_SCOPE_SHARE_ON_LINKEDIN);
        case LinkedInScope.COMPANY_ADMIN:
          return scopeConvert.add(_SCOPE_COMPANY_ADMIN);
        case LinkedInScope.MEMBER_SOCIAL:
          return scopeConvert.add(_SCOPE_MEMBER_SOCIAL);
      }
    });
    return scopeConvert.join(" ");
  }

  /// Returns [String] email address from LinkedIn
  ///
  /// Throws [LinkedInException] when network call fails or returns some error
  ///
  /// Please make sure the [LinkedInScope.EMAIL_ADDRESS] is used before auth, else this request will fail with a status code 500
  ///
  static Future<String> getEmailAddress(String token) async {
    final headers = {"Authorization": "Bearer $token"};
    Map<String, String> params = {
      "q": "members",
      "projection": "(elements*(handle~))"
    };
    var url = Uri.https(_API_URL, _EMAIL_API_PATH, params);
    var res = await http.get(url, headers: headers);
    if (res.statusCode ~/ 10 != 20) {
      throw LinkedInException(
          "Cannot fetch basic profile [${res.statusCode.toString()}]: ${res
              .body}");
    }
    return json.decode(res.body)["elements"][0]["handle~"]["emailAddress"];
  }

  static Future<Map<String, dynamic>> _getProfile(String token) async {
    final headers = {"Authorization": "Bearer $token"};
    Uri url = Uri.https(_API_URL, _PROFILE_API_PATH);
    var res = await http.get(url, headers: headers);
    if (res.statusCode ~/ 10 != 20) {
      throw LinkedInException(
          "Cannot fetch basic profile [${res.statusCode.toString()}]: ${res
              .body}");
    }
    print(res.body);
    return json.decode(res.body);
  }
}