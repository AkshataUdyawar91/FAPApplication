import 'web_redirect_stub.dart'
    if (dart.library.html) 'web_redirect_web.dart';

/// Cross-platform redirect helper.
/// On web, redirects the browser. On other platforms, does nothing.
class WebRedirectHelper {
  static void redirect(String url) => performRedirect(url);
}
