import Link from 'next/link';
import AdminClient from './admin-client';

export default function Page(){
  return <>
    <Link
      href="/phase11"
      className="btn"
      style={{position:'fixed',left:16,top:16,zIndex:1000}}
    >
      إدارة إذاعة ترتيل الافتراضية
    </Link>
    <AdminClient/>
  </>;
}
