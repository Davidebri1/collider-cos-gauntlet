// Start page and search for the in-app browser.
// With the Collider server, pages load through its /api/page proxy and search
// uses DuckDuckGo. With no server (static hosting such as GitHub Pages) pages
// are framed directly, and DuckDuckGo refuses to be framed (the browser shows
// its broken-page icon), so start page and search use Wikipedia, which allows
// framing (v8.3, D41).
import '../../core/api/collider_api.dart';

String browserStartUrl() =>
    ColliderApi.instance.online ? 'https://html.duckduckgo.com/html/' : 'https://www.wikipedia.org/';

String browserSearchUrl(String q) => ColliderApi.instance.online
    ? 'https://html.duckduckgo.com/html/?q=${Uri.encodeComponent(q)}'
    : 'https://en.wikipedia.org/w/index.php?search=${Uri.encodeComponent(q)}';
