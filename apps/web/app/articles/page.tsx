import type { Metadata } from "next";
import Link from "next/link";
import { listPublishedArticles } from "@/lib/articles/repository";

export const metadata: Metadata = { title: "Articles" };
export const revalidate = 300;

export default async function ArticlesPage() {
  const articles = await listPublishedArticles({ limit: 50 });

  return (
    <div className="page-shell">
      <p className="eyebrow">The archive</p>
      <h1>Climate notes</h1>
      <div className="article-grid">
        {articles.map((article) => (
          <Link className="article-card" href={`/articles/${article.slug}`} key={article.id}>
            <span className="chip">{article.topic}</span>
            <h3>{article.title}</h3>
            <p>{article.excerpt}</p>
          </Link>
        ))}
        {articles.length === 0 && <p>No articles have been published yet.</p>}
      </div>
    </div>
  );
}
