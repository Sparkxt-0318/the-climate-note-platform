import type { ArticleGeneration } from "@/lib/articles/schema";

export function ClimateSummary({ generation }: { generation: ArticleGeneration }) {
  const rows = [
    ["What is happening?", generation.summary.problem],
    ["Why does it matter?", generation.summary.whyItMatters],
    ["What can we do?", generation.summary.whatWeCanDo],
  ] as const;

  return (
    <section className="summary-card" aria-labelledby="summary-title">
      <p className="eyebrow">The climate note</p>
      <h2 id="summary-title">The simple version</h2>
      <div className="summary-grid">
        {rows.map(([title, copy]) => (
          <div key={title}>
            <h3>{title}</h3>
            <p>{copy}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
