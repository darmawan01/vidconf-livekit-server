import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

const String apiKey = 'API4AE2CE992EB41BFF9E0DC00B052A6EEB';
const String apiSecret = 'dwA6572h8HXL+S5V52AP431TEZwF8RErIkfoqlwrvio=';

String _base64UrlEncodeWithoutPadding(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

List<int> _decodeApiSecret(String apiSecret) {
  try {
    return base64.decode(apiSecret);
  } catch (e) {
    return utf8.encode(apiSecret);
  }
}

String _generateRoomCreationToken() {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final exp = now + 300;

  final header = {'alg': 'HS256', 'typ': 'JWT'};

  final claims = {
    'iss': apiKey,
    'exp': exp,
    'nbf': now,
    'sub': 'room-creator',
    'video': {
      'roomCreate': true,
    },
    'name': 'room-creator',
  };

  final encodedHeader = _base64UrlEncodeWithoutPadding(
    utf8.encode(jsonEncode(header)),
  );
  final encodedClaims = _base64UrlEncodeWithoutPadding(
    utf8.encode(jsonEncode(claims)),
  );

  final secretBytes = _decodeApiSecret(apiSecret);
  final signature = Hmac(sha256, secretBytes);
  final digest = signature.convert(
    utf8.encode('$encodedHeader.$encodedClaims'),
  );

  final encodedSignature = _base64UrlEncodeWithoutPadding(digest.bytes);

  return '$encodedHeader.$encodedClaims.$encodedSignature';
}

Future<bool> createRoom(String serverUrl, String roomName) async {
  try {
    final httpUrl = serverUrl.replaceFirst('ws://', 'http://').replaceFirst('wss://', 'https://');
    final url = Uri.parse('$httpUrl/twirp/livekit.RoomService/CreateRoom');

    final createToken = _generateRoomCreationToken();

    final requestBody = {
      'name': roomName,
      'empty_timeout': 600,
      'max_participants': 20,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $createToken',
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return true;
    } else if (response.statusCode == 409) {
      return true;
    } else {
      return false;
    }
  } catch (e) {
    return false;
  }
}

