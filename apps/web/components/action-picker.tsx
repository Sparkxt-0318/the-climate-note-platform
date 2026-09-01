import type { ArticleGeneration } from "@/lib/articles/schema";

export function ActionPicker({ generation }: { generation: ArticleGeneration }) {
  return (
    <section className="action-section" aria-labelledby="action-title">
      <p className="eyebrow">Reflection</p>
      <h2 id="action-title">Write your climate note!</h2>
      <p>Choose one specific action to carry into your week. Saving and tracking will be available in the iPhone app.</p>
      <div className="action-grid">
        {generation.suggestedActions.map((action, index) => (
          <article className="note-card" key={action.id}>
            <span className="action-number">0{index + 1}</span>
            <h3>{action.title}</h3>
            <p>{action.instruction}</p>
            <span className="action-cadence">{action.cadence}</span>
          </article>
        ))}
        <article className="note-card note-card-custom">
          <span className="action-number">04</span>
          <h3>Write your own</h3>
          <p>Create a private action or reflection in the iPhone app.</p>
        </article>
      </div>
    </section>
  );
}
