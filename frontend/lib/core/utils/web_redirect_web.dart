// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation: redirects the browser to the given URL.
void performRedirect(String url) {
  html.window.location.href = url;
}
