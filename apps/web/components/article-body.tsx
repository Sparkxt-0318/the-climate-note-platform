import { Fragment, type ReactNode } from "react";
import type { ArticleBlock } from "@/lib/articles/schema";

export function ArticleBody({ blocks, afterIntroduction }: { blocks: ArticleBlock[]; afterIntroduction?: ReactNode }) {
  const introductionIndex = Math.max(0, blocks.findIndex((block) => block.type === "paragraph"));

  return (
    <div className="article-body">
      {blocks.map((block, index) => {
        const key = `${block.type}-${index}`;
        let content: ReactNode;

        if (block.type === "heading") {
          content = block.level === 2 ? <h2>{block.text}</h2> : <h3>{block.text}</h3>;
        } else if (block.type === "bulletedList") {
          content = (
            <ul>
              {block.items.map((item, itemIndex) => <li key={`${itemIndex}-${item}`}>{item}</li>)}
            </ul>
          );
        } else if (block.type === "numberedList") {
          content = (
            <ol>
              {block.items.map((item, itemIndex) => <li key={`${itemIndex}-${item}`}>{item}</li>)}
            </ol>
          );
        } else {
          content = <p>{block.text}</p>;
        }

        return (
          <Fragment key={key}>
            {content}
            {afterIntroduction && index === introductionIndex ? afterIntroduction : null}
          </Fragment>
        );
      })}
    </div>
  );
}
