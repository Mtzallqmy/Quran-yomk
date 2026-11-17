import { notFound } from 'next/navigation';
import documents from '../../../../../docs/legal/documents.json';

export function generateStaticParams() {
  return documents.map(document => ({ document: document.id }));
}

export default async function LegalPage({ params }: { params: Promise<{ document: string }> }) {
  const { document: id } = await params;
  const document = documents.find(item => item.id === id);
  if (!document) notFound();
  return <main id="main-content" style={{ maxWidth: 760, margin: 'auto', padding: '32px 20px', lineHeight: 1.9 }}>
    <nav aria-label="الوثائق القانونية"><a href="/legal/privacy">الخصوصية</a> · <a href="/legal/terms">الشروط</a></nav>
    <h1>{document.title}</h1>
    <p>آخر تحديث: <time dateTime={document.updated}>{document.updated}</time></p>
    {document.sections.map(section => <section key={section.title}><h2>{section.title}</h2><p>{section.body}</p></section>)}
  </main>;
}
