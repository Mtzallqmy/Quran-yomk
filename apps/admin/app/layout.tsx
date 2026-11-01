import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import './globals.css';

export const metadata:Metadata={
  title:'ترتيل — لوحة الإدارة',
  description:'لوحة إدارة ترتيل للمحتوى والإذاعة',
  applicationName:'Tarteel Admin',
};

export default function RootLayout({children}:{children:ReactNode}){
  return <html lang="ar" dir="rtl"><body><a className="skip-link" href="#main-content">تخطي إلى المحتوى</a>{children}</body></html>;
}
