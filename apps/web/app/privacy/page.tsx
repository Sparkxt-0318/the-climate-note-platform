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
      <p className="legal-updated">Effective October 11, 2026</p>

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
            <strong>Account information:</strong> a Firebase user identifier, the email address or
            private relay address supplied by Apple or Google, and provider profile information such
            as a display name when your selected provider supplies it.
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
        <h2>Optional anonymous community impact</h2>
        <p>
          Community impact participation is off by default. If you choose it in Account, we count
          only completed actions that have an article-specific, versioned CO₂e factor. We do not add
          your notes, reflection text, account identity, article history, or personal total to the
          public result.
        </p>
        <p>
          We keep a private server-side receipt with the accepted factor version and amount so we can
          maintain the aggregate accurately. The public total appears only after at least ten distinct
          people have eligible completed actions, and it is rounded. Turning the setting off or
          deleting your account removes your eligible receipt contributions from future totals.
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
          Google Gemini or Groq for article-only enrichment when configured; and Pexels for licensed article
          photography. Photo searches contain article topics rather than private user content. Apple,
          Google, Vercel, Groq, and Pexels operate under their own terms and
          privacy disclosures. We configure them for the roles described here and do not intentionally
          send private reflection text to article-enrichment or photography services.
        </p>
      </section>

      <section id="choices">
        <h2>Your choices and account deletion</h2>
        <p>
          Notifications are off by default and can be changed in the app. In Account settings, you can
          export your synced account data or permanently delete your account. The export includes
          authentication profile details, synced notes and actions, your community-impact preference
          and receipts, and essential abuse-prevention metadata. Unfinished drafts that have not synced
          remain only on the current device and are not part of the server export. Account deletion
          removes account-scoped local drafts on that device and removes the account, synced private
          content, and authentication record from our active systems. It also queues removal of eligible
          community-impact receipts from future totals; temporary reconciliation records are deleted
          after successful processing. If you need help, email
          {" "}<a href="mailto:theclimatenote@gmail.com">theclimatenote@gmail.com</a>.
        </p>
      </section>

      <section>
        <h2>Retention and security</h2>
        <p>
          Synced private content is retained while your account remains active and is removed from the
          active service when you use the in-app deletion control. Local unfinished drafts remain on the
          device until saved, discarded, or the account is deleted. Hosting and authentication providers
          may retain limited backup, fraud-prevention, or security records under their own retention
          schedules or where law requires them. We use access controls, encrypted network connections,
          protected local files, and per-user database rules, but no internet service can guarantee
          absolute security.
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
