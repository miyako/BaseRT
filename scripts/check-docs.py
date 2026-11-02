#!/usr/bin/env python3
"""Check static Pages assets, relative links and fragment targets without dependencies."""

from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1] / "docs"


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__(convert_charrefs=True)
        self.path = path
        self.ids = set()
        self.links = []
        self.feed(path.read_text())

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            if attrs["id"] in self.ids:
                raise ValueError(f"{self.path}: duplicate id {attrs['id']}")
            self.ids.add(attrs["id"])
        for key in ("href", "src"):
            if key in attrs:
                if not attrs[key]:
                    raise ValueError(f"{self.path}: empty {key}")
                self.links.append(attrs[key])


def main():
    pages = {path.resolve(): Page(path) for path in ROOT.rglob("*.html")}
    if not pages or not (ROOT / "index.html").exists():
        raise ValueError("docs/index.html is required")
    for path, page in pages.items():
        for link in page.links:
            url = urlsplit(link)
            if url.scheme or url.netloc:
                if url.scheme not in ("https", "http", "mailto"):
                    raise ValueError(f"{path}: unexpected link scheme: {link}")
                continue
            if url.path.startswith("/"):
                raise ValueError(f"{path}: root-relative link breaks project Pages: {link}")
            target = (path.parent / unquote(url.path)).resolve() if url.path else path
            if target.is_dir():
                target /= "index.html"
            if not target.is_relative_to(ROOT.resolve()) or not target.is_file():
                raise ValueError(f"{path}: missing/out-of-site target: {link}")
            if url.fragment and target in pages:
                if unquote(url.fragment) not in pages[target].ids:
                    raise ValueError(f"{path}: missing fragment: {link}")
    print(f"Checked {len(pages)} HTML pages and all local links/assets.")


if __name__ == "__main__":
    main()
