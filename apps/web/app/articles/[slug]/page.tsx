import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ActionPicker } from "@/components/action-picker";
import { ArticleBody } from "@/components/article-body";
import { ClimateSummary } from "@/components/climate-summary";
import { getPublishedArticleBySlug } from "@/lib/articles/repository";

type PageProps = { params: Promise<{ slug: string }> };

function ArticleFigure({ article }: { article: NonNullable<Awaited<ReturnType<typeof getPublishedArticleBySlug>>> }) {
  if (!article.coverAsset) return null;
  return (
    <figure className="article-figure">
      {/* The ingestion pipeline stores trusted, licensed media URLs. */}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={article.coverAsset.url} alt={article.coverAsset.altText} />
      <figcaption>
        {article.coverAsset.caption} {article.coverAsset.attribution}
        {article.coverAsset.sourceUrl && <> · <a href={article.coverAsset.sourceUrl}>{article.coverAsset.license}</a></>}
      </figcaption>
    </figure>
  );
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug } = await params;
  const article = await getPublishedArticleBySlug(slug);
  return article ? { title: article.title, description: article.excerpt } : {};
}

export default async function ArticlePage({ params }: PageProps) {
  const { slug } = await params;
  const article = await getPublishedArticleBySlug(slug);
  if (!article) notFound();

  return (
    <article className="article-shell">
      <header className="article-header">
        <span className="chip">{article.topic}</span>
        <h1>{article.title}</h1>
        <p>{article.excerpt}</p>
        <div className="article-meta">
          {article.author && <span>By {article.author}</span>}
          <span>{article.readingMinutes} min read</span>
        </div>
      </header>

      {article.coverAsset && article.generation?.visualPlan.placement === "cover" && (
        <ArticleFigure article={article} />
      )}

      <ArticleBody
        blocks={article.contentBlocks}
        afterIntroduction={
          article.coverAsset && article.generation?.visualPlan.placement === "after-introduction"
            ? <ArticleFigure article={article} />
            : undefined
        }
      />

      {article.sourceLinks.length > 0 && (
        <section className="sources" aria-labelledby="sources-heading">
          <h2 id="sources-heading">Sources</h2>
          <ol>
            {article.sourceLinks.map((source) => (
              <li key={source.url}><a href={source.url}>{source.label}</a></li>
            ))}
          </ol>
        </section>
      )}

      {Object.keys(article.externalLinks).length > 0 && (
        <section className="external-links" aria-labelledby="external-links-heading">
          <h2 id="external-links-heading">Also published on</h2>
          <div>
            {article.externalLinks.instagram && <a href={article.externalLinks.instagram}>Instagram</a>}
            {article.externalLinks.substack && <a href={article.externalLinks.substack}>Substack</a>}
            {article.externalLinks.medium && <a href={article.externalLinks.medium}>Medium</a>}
          </div>
        </section>
      )}

      {article.generation && (
        <>
          <ClimateSummary generation={article.generation} />
          <ActionPicker generation={article.generation} />
        </>
      )}
    </article>
  );
}
