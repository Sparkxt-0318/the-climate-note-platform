"use client";
import { FormEvent, useCallback, useEffect, useState } from "react";
import { GoogleAuthProvider, onAuthStateChanged, signInWithPopup, signOut, type User } from "firebase/auth";
import { getClientAuth } from "@/lib/firebase/client";

type AdminArticle = {
  id: string;
  title: string;
  status: string;
  externalLinks: { instagram?: string; substack?: string; medium?: string };
};

type IngestionItem = {
  name: string;
  status: "published" | "unchanged" | "failed" | "ignored";
  detail?: string;
};

async function adminFetch(user: User, input: string, init?: RequestInit) {
  const token = await user.getIdToken();
  const response = await fetch(input, {
    ...init,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json", ...init?.headers },
  });
  const body = await response.json();
  if (!response.ok) throw new Error(body.error || "The request failed.");
  return body;
}

export default function AdminPage() {
  const [user, setUser] = useState<User | null>(null);
  const [articles, setArticles] = useState<AdminArticle[]>([]);
  const [message, setMessage] = useState("Loading…");
  const [working, setWorking] = useState(false);

  const loadArticles = useCallback(async (activeUser: User) => {
    try {
      const body = await adminFetch(activeUser, "/api/admin/articles");
      setArticles(body.articles);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Articles could not be loaded.");
    }
  }, []);

  useEffect(() => {
    try {
      return onAuthStateChanged(getClientAuth(), (nextUser) => {
        setUser(nextUser);
        setMessage(nextUser ? "Ready" : "Sign in with the approved administrator account.");
        if (nextUser) void loadArticles(nextUser);
      });
    } catch (error) {
      queueMicrotask(() => setMessage(error instanceof Error ? error.message : "Firebase is not configured."));
    }
  }, [loadArticles]);

  async function login() {
    setWorking(true);
    try {
      await signInWithPopup(getClientAuth(), new GoogleAuthProvider());
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Sign-in failed.");
    } finally {
      setWorking(false);
    }
  }

  async function syncNow() {
    if (!user) return;
    setWorking(true);
    setMessage("Checking Drive and publishing validated DOCX files…");
    try {
      const body = await adminFetch(user, "/api/admin/ingest", { method: "POST" });
      const failed = (body.items as IngestionItem[]).find((item) => item.status === "failed");
      const result = `Finished: ${body.counts.published} published, ${body.counts.unchanged} unchanged, ${body.counts.failed} failed.`;
      setMessage(failed?.detail ? `${result} ${failed.name}: ${failed.detail}` : result);
      await loadArticles(user);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Sync failed.");
    } finally {
      setWorking(false);
    }
  }

  return (
    <div className="page-shell admin-shell">
      <p className="eyebrow">Private workspace</p>
      <h1>Publishing admin</h1>
      <p className="admin-status" role="status">{message}</p>
      {!user ? (
        <button className="primary-button" type="button" onClick={login} disabled={working}>Continue with Google</button>
      ) : (
        <>
          <div className="admin-toolbar">
            <button className="primary-button" type="button" onClick={syncNow} disabled={working}>Sync Drive now</button>
            <button className="secondary-button" type="button" onClick={() => signOut(getClientAuth())}>Sign out</button>
          </div>
          <div className="admin-list">
            {articles.map((article) => <ArticleLinks key={article.id} article={article} user={user} onSaved={() => loadArticles(user)} />)}
          </div>
        </>
      )}
    </div>
  );
}

function ArticleLinks({ article, user, onSaved }: { article: AdminArticle; user: User; onSaved: () => void }) {
  const [working, setWorking] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setWorking(true);
    const data = new FormData(event.currentTarget);
    try {
      await adminFetch(user, `/api/admin/articles/${article.id}/links`, {
        method: "PATCH",
        body: JSON.stringify({
          instagram: data.get("instagram"), substack: data.get("substack"), medium: data.get("medium"),
        }),
      });
      onSaved();
    } finally {
      setWorking(false);
    }
  }

  return (
    <form className="admin-card" onSubmit={submit}>
      <div><span className="chip">{article.status}</span><h2>{article.title}</h2></div>
      {(["instagram", "substack", "medium"] as const).map((service) => (
        <label key={service}>{service}<input name={service} type="url" defaultValue={article.externalLinks[service] || ""} placeholder={`https://${service}.com/…`} /></label>
      ))}
      <button className="secondary-button" disabled={working}>{working ? "Saving…" : "Save links"}</button>
    </form>
  );
}
