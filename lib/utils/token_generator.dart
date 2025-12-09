import 'dart:convert';
import 'package:crypto/crypto.dart';

String generateLiveKitToken({
  required String apiKey,
  required String apiSecret,
  required String roomName,
  required String participantName,
}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final exp = now + 3600;

  final header = {
    'alg': 'HS256',
    'typ': 'JWT',
  };

  final claims = {
    'iss': apiKey,
    'exp': exp,
    'nbf': now,
    'sub': participantName,
    'video': {
      'room': roomName,
      'roomJoin': true,
      'canPublish': true,
      'canSubscribe': true,
    },
    'name': participantName,
  };

  final encodedHeader = base64Url.encode(utf8.encode(jsonEncode(header)));
  final encodedClaims = base64Url.encode(utf8.encode(jsonEncode(claims)));

  final signature = Hmac(sha256, utf8.encode(apiSecret));
  final digest = signature.convert(utf8.encode('$encodedHeader.$encodedClaims'));

  return '$encodedHeader.$encodedClaims.${base64Url.encode(digest.bytes)}';
}

