import Link from "next/link";
import { listPublishedArticles } from "@/lib/articles/repository";

export const revalidate = 300;

export default async function HomePage() {
  const articles = await listPublishedArticles({ limit: 6 });

  return (
    <div className="page-shell">
      <section className="hero" aria-labelledby="home-title">
        <div>
          <p className="eyebrow">A weekly climate newsletter</p>
          <h1 id="home-title">Understand more. Change one thing.</h1>
          <p className="hero-copy">
            Clear climate stories for young readers, followed by one practical note you can
            carry into the week.
          </p>
        </div>
        <div className="hero-card" aria-label="One article and one action every week">
          <span className="hero-card-number">1×</span>
          <p>
            One focused article.
            <br />
            One action worth trying.
          </p>
        </div>
      </section>

      <section aria-labelledby="latest-heading">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Latest notes</p>
            <h2 id="latest-heading">Read what matters now</h2>
          </div>
          <Link href="/articles">View all</Link>
        </div>

        <div className="article-grid">
          {articles.length > 0 ? (
            articles.map((article) => (
              <Link className="article-card" href={`/articles/${article.slug}`} key={article.id}>
                <span className="chip">{article.topic}</span>
                <h3>{article.title}</h3>
                <p>{article.excerpt}</p>
              </Link>
            ))
          ) : (
            <div className="article-card">
              <span className="chip">Publishing soon</span>
              <h3>The first Climate Note is on its way.</h3>
              <p>The automated Drive pipeline will place the newest article here.</p>
            </div>
          )}
        </div>
      </section>
    </div>
  );
}
