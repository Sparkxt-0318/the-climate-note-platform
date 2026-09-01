import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Support",
  description: "Support and account help for The Climate Note.",
};

export default function SupportPage() {
  return (
    <article className="legal-shell">
      <p className="eyebrow">Support</p>
      <h1>How can we help?</h1>
      <p className="hero-copy">
        Email <a href="mailto:theclimatenote@gmail.com">theclimatenote@gmail.com</a>. Please do not
        include passwords, sign-in codes, or other sensitive credentials.
      </p>

      <section>
        <h2>Reading articles</h2>
        <p>
          Articles are available without an account. If the feed cannot load, confirm that your device
          is online and try again. You can also read published notes on this website.
        </p>
      </section>

      <section>
        <h2>Sign-in help</h2>
        <p>
          The iPhone app supports native Sign in with Apple and the official Google Sign-In flow,
          presented in a secure sheet within the app. The app does not send you to the default
          browser to register. If sign-in is canceled, reopen Account and try the provider again.
        </p>
      </section>

      <section>
        <h2>Export or delete your account</h2>
        <p>
          Open <strong>Account</strong> in the app to export your private data or select
          <strong> Delete account</strong>. Account deletion permanently removes your Firebase account,
          reflections, action history, and related private profile data. Apple may ask you to sign in
          again so the app can securely revoke your Sign in with Apple authorization.
        </p>
      </section>

      <section>
        <h2>Privacy</h2>
        <p>
          Read the full <Link href="/privacy">Privacy Policy</Link>, including data practices,
          notification choices, retention, and contact information.
        </p>
      </section>
    </article>
  );
}
