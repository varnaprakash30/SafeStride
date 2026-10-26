import 'package:http/http.dart' as http;

/// Convenience fetch function (uses `package:http`)
Future<HttpResponse> fetch(Uri url) async {
  final resp = await http.get(url);
  return HttpResponse.fromHttp(resp);
}

// Typed response holder instead of using reserved identifier `get`
class HttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  HttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  factory HttpResponse.fromHttp(http.Response r) =>
      HttpResponse(statusCode: r.statusCode, body: r.body, headers: r.headers);
}
