"""Generate the shareable single-page build from index.html.

The Artifact host injects its own <!doctype>/<head>/<body>, so this strips
the document wrapper and disables the two features that only make sense in
a real deployment (service worker, home-screen install prompt).

    python tools/build-artifact.py
"""
import io
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "index.html")
DST = os.path.join(ROOT, "dist", "rot-check.html")

src = io.open(SRC, encoding="utf-8").read()

title = re.search(r"<title>.*?</title>", src, re.S).group(0)
fonts = re.findall(r'<link rel="(?:preconnect|stylesheet)"[^>]*fonts\.[^>]*>', src)
style = re.search(r"<style>.*?</style>", src, re.S).group(0)
body = re.search(r"<body>(.*?)</body>", src, re.S).group(1)

# The artifact sandbox has no origin to register a worker against and no
# install surface, so drop both rather than let them fail quietly.
body = re.sub(
    r'  if \("serviceWorker" in navigator\) \{.*?\n  \}\n',
    "  /* service worker omitted in the shareable build */\n",
    body, flags=re.S,
)
body = body.replace(
    'if (!dismissed && !standalone) el.install.classList.add("on");',
    "/* install prompt omitted in the shareable build */",
)
body = body.replace(
    "if (isIOS && !standalone && !dismissed) {",
    "if (false) {",
)
body = body.replace(
    "House ad units with fictional brands until a network is wired.<br>See README.md to switch on AdMob or H5 Games Ads.",
    "House ad units with fictional brands. The published build ships with AdMob and H5 Games Ads adapters ready to switch on.",
)

# The artifact sandbox blocks fetch, so the shared deck rides along inline.
deck_path = os.path.join(ROOT, "deck.json")
deck_tag = ""
if os.path.exists(deck_path):
    deck_tag = "<script>window.__DECK = " + io.open(deck_path, encoding="utf-8").read() + ";</script>\n"

out = "\n".join([title] + fonts + [style, deck_tag + body.strip(), ""])


def escape_non_ascii(text):
    """The host supplies its own <head>, so this build cannot rely on a
    charset declaration being present. Escape every non-ASCII character
    instead: \\uXXXX inside <script> (HTML entities are not decoded there),
    numeric entities everywhere else."""
    parts = re.split(r"(<script>.*?</script>)", text, flags=re.S)
    for i, part in enumerate(parts):
        js = part.startswith("<script>")
        parts[i] = "".join(
            ch if ord(ch) < 128
            else ("\\u%04x" % ord(ch)) if js
            else ("&#%d;" % ord(ch))
            for ch in part
        )
    return "".join(parts)


out = escape_non_ascii(out)
assert all(ord(c) < 128 for c in out), "non-ASCII survived escaping"

os.makedirs(os.path.dirname(DST), exist_ok=True)
io.open(DST, "w", encoding="utf-8").write(out)
print("wrote dist/rot-check.html  (%d KB)" % (len(out.encode("utf-8")) // 1024))
