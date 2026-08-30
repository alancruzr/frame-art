#!/usr/bin/env python3
"""Regenerate web/*.html and netlify/lib/viewer-html.ts from viewer.template.html."""
from pathlib import Path
import html as htmlmod

root = Path(__file__).resolve().parents[1]
template = (root / "netlify/lib/viewer.template.html").read_text()

def fill(title: str, poster_abs: str) -> str:
    safe_title = htmlmod.escape(title or "Frame Studio", quote=True)
    safe_poster = htmlmod.escape(poster_abs, quote=True)
    page_title = f"{safe_title} — Frame Studio"
    return (
        template.replace("@@PAGE_TITLE@@", page_title)
        .replace("@@SAFE_TITLE@@", safe_title)
        .replace("@@SAFE_POSTER@@", safe_poster)
    )

def main() -> None:
    pages = [
        (root / "web/index.html", "Frame Studio", "https://frame-studio.netlify.app/poster.jpg"),
        (
            root / "web/o/1017CBB1-3D45-4F32-920C-58769100A091/index.html",
            "Starry Night",
            "https://frame-studio.netlify.app/o/1017CBB1-3D45-4F32-920C-58769100A091/poster.jpg",
        ),
        (
            root / "web/o/6D5F2655-E318-4545-AAA8-7FD242C110A6/index.html",
            "Obra",
            "https://frame-studio.netlify.app/o/6D5F2655-E318-4545-AAA8-7FD242C110A6/poster.jpg",
        ),
    ]
    for path, title, poster in pages:
        path.write_text(fill(title, poster))
        print("wrote", path)
    ts_html = (
        template.replace("@@PAGE_TITLE@@", "${pageTitle}")
        .replace("@@SAFE_TITLE@@", "${safeTitle}")
        .replace("@@SAFE_POSTER@@", "${safePoster}")
    )
    ts = """export function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (ch) => {
    switch (ch) {
      case "&": return "&amp;";
      case "<": return "&lt;";
      case ">": return "&gt;";
      case '"': return "&quot;";
      case "'": return "&#39;";
      default: return ch;
    }
  });
}

export function viewerHTML(title: string, posterAbs: string): string {
  const safeTitle = escapeHtml(title || "Frame Studio");
  const safePoster = escapeHtml(posterAbs);
  const pageTitle = `${safeTitle} — Frame Studio`;
  return `""" + ts_html + "`;\n}\n"
    out = root / "netlify/lib/viewer-html.ts"
    out.write_text(ts)
    print("wrote", out)

if __name__ == "__main__":
    main()
