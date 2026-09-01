import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "How The Climate Note handles account, reflection, and app data.",
};

export default function PrivacyPage() {
  return (
    <article className="legal-shell">
      <p className="eyebrow">Privacy policy</p>
      <h1>Your notes belong to you.</h1>
      <p className="legal-updated">Effective August 29, 2026</p>

      <section>
        <h2>What this policy covers</h2>
        <p>
          The Climate Note provides public climate articles and optional private accounts for saving
          reflections, actions, completion history, impact estimates, and notification preferences.
          You can read every published article without creating an account.
        </p>
      </section>

      <section>
        <h2>Information we collect</h2>
        <ul>
          <li>
            <strong>Account information:</strong> a Firebase user identifier and the email address or
            private relay address supplied by Apple or Google when you choose to sign in.
          </li>
          <li>
            <strong>Private content:</strong> reflections and actions you save, completion dates,
            impact estimates, and notification preferences.
          </li>
          <li>
            <strong>Essential technical information:</strong> security, authentication, and service
            logs processed by our hosting providers to operate and protect the service.
          </li>
        </ul>
        <p>
          We do not sell personal information, use behavioral advertising, track you across other
          companies&apos; apps or websites, or make private reflections public.
        </p>
      </section>

      <section>
        <h2>How information is used</h2>
        <p>
          We use account and private-content data only to authenticate you, sync your private Climate
          Notes, show your progress, calculate clearly labeled estimates for supported actions, send
          notifications you explicitly enable, provide data exports, prevent abuse, and respond to
          support requests. Private reflections are not used to train public AI models.
        </p>
      </section>

      <section>
        <h2>AI and published articles</h2>
        <p>
          AI may create a labeled summary and three article-specific action suggestions from an
          editor-approved article. The original article is stored and published without AI rewriting.
          Private user reflections are not sent to the article-enrichment AI services.
        </p>
      </section>

      <section>
        <h2>Service providers</h2>
        <p>
          We use Google Firebase for authentication, private data, and notifications;
          Vercel for website and API hosting; Google Drive for editor-controlled source documents;
          and a configured AI provider for article-only enrichment. Apple and Google process
          sign-in data under their own privacy terms. These providers process information only as
          needed to deliver their services to us.
        </p>
      </section>

      <section id="choices">
        <h2>Your choices and account deletion</h2>
        <p>
          Notifications are off by default and can be changed in the app. In Account settings, you can
          export your private data or permanently delete your account. Deletion removes the account,
          private notes, action history, and related profile data from our active systems. If you need
          help, email <a href="mailto:theclimatenote@gmail.com">theclimatenote@gmail.com</a>.
        </p>
      </section>

      <section>
        <h2>Retention and security</h2>
        <p>
          Private content is retained while your account remains active and is deleted when you use
          the in-app deletion control, except where a short-lived backup or security record must be
          retained for legal, fraud-prevention, or service-integrity reasons. We use access controls,
          encrypted network connections, and per-user database rules, but no internet service can
          guarantee absolute security.
        </p>
      </section>

      <section>
        <h2>Young readers</h2>
        <p>
          The Climate Note is intended for people age 13 and older and is not placed in Apple&apos;s Kids
          Category. We do not knowingly collect personal information from children under 13. A parent
          or guardian who believes a child under 13 created an account can contact us for deletion.
        </p>
      </section>

      <section>
        <h2>Updates and contact</h2>
        <p>
          We may update this policy when the service changes and will revise the effective date above.
          Questions or privacy requests can be sent to
          {" "}
          <a href="mailto:theclimatenote@gmail.com">theclimatenote@gmail.com</a>.
        </p>
      </section>
    </article>
  );
}
