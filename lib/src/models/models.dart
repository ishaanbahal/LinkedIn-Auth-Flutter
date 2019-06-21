import 'dart:convert';


import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LinkedInRequest {
  /// Random string generated, must be verified once returned from server
  final String state;

  /// Request URL to hit for LinkedIn login workflow
  final String url;

  LinkedInRequest(this.state, this.url);

  bool verifyState(String state) {
    if (this.state == state) {
      return true;
    }
    return false;
  }
}

class AccessToken {
  final String token;
  DateTime expiry;

  AccessToken(this.token, int expiry) {
    this.expiry = DateTime.now().add(Duration(seconds: expiry));
  }
}

/// Scope enum for accessing user info. Will be shown on the login prompt.
///
/// Read more here: https://docs.microsoft.com/en-us/linkedin/consumer/
enum LinkedInScope {
  /// Requests the r_emailaddress scope
  EMAIL_ADDRESS,

  /// Requests the r_basicprofile scope
  BASIC_PROFILE,

  /// Requests the r_liteprofile scope
  LITE_PROFILE,

  /// Requests the w_share scope
  SHARE_ON_LINKEDIN, // This is a write only API. Please check permissions scopes on https://docs.microsoft.com/en-us/linkedin/

  /// Requests the rw_company_admin scope
  COMPANY_ADMIN, // This is a read-write API. Please check permissions scopes on https://docs.microsoft.com/en-us/linkedin/

  /// Requests the w_member_social scope
  MEMBER_SOCIAL // This is a write only API. Please check permissions scopes on https://docs.microsoft.com/en-us/linkedin/
}

class LinkedInException implements Exception {
  String cause;

  LinkedInException(this.cause);
}

/// Read more about Lite Profile fields at: https://docs.microsoft.com/en-us/linkedin/shared/references/v2/profile/lite-profile?context=linkedin/consumer/context
class LiteProfile {
  final String id;
  final MultiLocaleString firstName, lastName, maidenName;
  final ProfileImage profileImage;

  LiteProfile(
      {@required this.id,
      @required this.firstName,
      @required this.lastName,
      @required this.maidenName,
      @required this.profileImage});

  /// Returns [LiteProfile] from parsed JSON object
  factory LiteProfile.fromJson(Map<String, dynamic> parsed) {
    return LiteProfile(
      id: parsed["id"] as String,
      firstName: MultiLocaleString.fromJson(
          parsed["firstName"] as Map<String, dynamic>),
      lastName: MultiLocaleString.fromJson(
          parsed["lastName"] as Map<String, dynamic>),
      maidenName: parsed.containsKey("maidenName")
          ? MultiLocaleString.fromJson(
              parsed["maidenName"] as Map<String, dynamic>)
          : MultiLocaleString(text: "", language: ""),
      profileImage: ProfileImage.fromJson(
          parsed["profilePicture"] as Map<String, dynamic>),
    );
  }

  @override
  String toString() {
    return "id:$id\nfirstName:${firstName.text}\nlastName:${lastName.text}\nmaidenName:${maidenName.text}\nprofileImage:${profileImage.urn}";
  }
}

/// Read more about Basic Profile Fields at: https://docs.microsoft.com/en-us/linkedin/shared/references/v2/profile/basic-profile?context=linkedin/consumer/context
///
/// Caveat: LinkedIn developer page might show you access to [LinkedInScope.BASIC_PROFILE], but it might not be the case
/// and you will see an exception. It requires special permission by LinkedIn for developer to get access to that info.
class BasicProfile {
  final String id,
      localizedFirstName,
      localizedLastName,
      localizedMaidenName,
      localizedHeadline,
      vanityName;
  final MultiLocaleString firstName, lastName, maidenName, headline;
  final ProfileImage profileImage;

  BasicProfile({
    @required this.id,
    @required this.firstName,
    @required this.lastName,
    @required this.maidenName,
    @required this.headline,
    @required this.profileImage,
    @required this.localizedFirstName,
    @required this.localizedLastName,
    @required this.localizedMaidenName,
    @required this.localizedHeadline,
    @required this.vanityName,
  });

  /// Returns [BasicProfile] from parsed JSON object
  factory BasicProfile.fromJson(Map<String, dynamic> parsed) {
    return BasicProfile(
      id: parsed["id"] as String,
      firstName: MultiLocaleString.fromJson(parsed["firstName"]),
      lastName: MultiLocaleString.fromJson(parsed["lastName"]),
      maidenName: MultiLocaleString.fromJson(parsed["maidenName"]),
      headline: MultiLocaleString.fromJson(parsed["headline"]),
      profileImage: ProfileImage.fromJson(
          parsed["profilePicture"] as Map<String, String>),
      localizedFirstName: parsed["localizedFirstName"] as String,
      localizedHeadline: parsed["localizedHeadline"] as String,
      localizedLastName: parsed["localizedLastName"] as String,
      localizedMaidenName: parsed["localizedMaidenName"] as String,
      vanityName: parsed["vanityName"] as String,
    );
  }

  @override
  String toString() {
    return "id:$id\nfirstName:${firstName.text}\nlastName:${lastName.text}\nmaidenName:${maidenName.text}\nvanityName:$vanityName\nheadline:$headline\nprofileImage:${profileImage.urn}";
  }
}

/// ProfileImage is a 100X100 image with a projection identifier displayImage
/// originalImage is not accessible without special permission from LinkedIn
class ProfileImage {
  static const _DISPLAY_IMAGE = "displayImage";
  static const _API_URI = "api.linkedin.com";
  static const _PROFILE_STREAM_PATH = "v2/me";
  static const Map<String, String> params = {
    "projection": "(profilePicture($_DISPLAY_IMAGE~:playableStreams))"
  };

  final String urn;
  String _url = "";

  ProfileImage(this.urn);

  /// Returns [ProfileImage] from parsed JSON object
  factory ProfileImage.fromJson(Map<String, dynamic> parsed) {
    return ProfileImage(parsed[_DISPLAY_IMAGE]);
  }

  /// Returns [String] url of the profile image from displayImage URN.
  /// Must be called to get the URL, linkedIn doesn't send the image URL in the
  /// profile fields, but send an URN value.
  ///
  /// Read more: https://docs.microsoft.com/en-us/linkedin/shared/references/v2/profile/profile-picture
  Future<String> getDisplayImageUrl(String token) async {
    final headers = {"Authorization": "Bearer $token"};
    if (_url.isNotEmpty) {
      return _url;
    }
    var projectionUri = Uri.https(_API_URI, _PROFILE_STREAM_PATH, params);
    var res = await http.get(projectionUri, headers: headers);
    if (res.statusCode ~/ 10 != 20) {
      throw LinkedInException("Failed to fetch image: ${res.body}");
    }
    Map<String, dynamic> parsed = json.decode(res.body);
    this._url = parsed["profilePicture"]["displayImage~"]["elements"][0]
        ["identifiers"][0]["identifier"];
    return _url;
  }
}

/// Date object for Multi locale string, read more at:
/// https://docs.microsoft.com/en-us/linkedin/shared/references/v2/object-types#multilocalestring
class MultiLocaleString {
  final String text, language;

  MultiLocaleString({@required this.text, @required this.language});

  /// Returns [MultiLocaleString] from parsed JSON object
  factory MultiLocaleString.fromJson(Map<String, dynamic> parsed) {
    var textMap = parsed["localized"] as Map<String, dynamic>;
    return MultiLocaleString(
      language: parsed["preferredLocale"]["language"] as String,
      text: textMap[textMap.keys.first] as String,
    );
  }
}
