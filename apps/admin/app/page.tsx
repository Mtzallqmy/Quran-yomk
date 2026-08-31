import Link from 'next/link';
import AdminClient from './admin-client';

export default function Page(){
  return <>
    <div style={{position:'fixed',left:16,top:16,zIndex:1000,display:'flex',gap:8,flexWrap:'wrap'}}>
      <Link href="/managed-radio" className="btn">Managed Radio — إذاعة ترتيل</Link>
      <Link href="/phase11" className="btn">إدارة إذاعة ترتيل الافتراضية</Link>
    </div>
    <AdminClient/>
  </>;
}
