import type { Metadata } from "next";

export const metadata: Metadata = { title: "About" };

export default function AboutPage() {
  return (
    <div className="page-shell">
      <p className="eyebrow">About us</p>
      <h1>Climate information that feels possible.</h1>
      <p className="hero-copy">
        The Climate Note makes environmental issues understandable for young readers and turns
        each story into a specific action. Questions or support requests can be sent to
        {" "}
        <a href="mailto:theclimatenote@gmail.com">theclimatenote@gmail.com</a>.
      </p>
    </div>
  );
}
