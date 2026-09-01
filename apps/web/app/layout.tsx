import type { Metadata, Viewport } from "next";
import Link from "next/link";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "The Climate Note",
    template: "%s — The Climate Note",
  },
  description:
    "A weekly climate newsletter that turns understanding into practical action.",
  applicationName: "The Climate Note",
};

export const viewport: Viewport = {
  colorScheme: "light dark",
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f7f8f5" },
    { media: "(prefers-color-scheme: dark)", color: "#111715" },
  ],
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>
        <a className="skip-link" href="#content">
          Skip to content
        </a>
        <header className="site-header">
          <Link className="wordmark" href="/" aria-label="The Climate Note home">
            <span className="book-mark" aria-hidden="true">
              <span />
            </span>
            <span>The Climate Note</span>
          </Link>
          <nav aria-label="Primary navigation">
            <Link href="/articles">Articles</Link>
            <Link href="/about">About</Link>
            <Link href="/support">Support</Link>
          </nav>
        </header>
        <main id="content">{children}</main>
        <footer className="site-footer">
          <p>Small notes. Real climate action.</p>
          <div className="footer-links">
            <Link href="/privacy">Privacy</Link>
            <Link href="/support">Support</Link>
            <a href="mailto:theclimatenote@gmail.com">theclimatenote@gmail.com</a>
          </div>
        </footer>
      </body>
    </html>
  );
}
