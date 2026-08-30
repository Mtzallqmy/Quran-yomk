import type { Metadata } from 'next';
import type { ReactNode } from 'react';
export const metadata:Metadata={title:'Tarteel Admin',description:'Tarteel backend and administration'};
export default function RootLayout({children}:{children:ReactNode}){return <html lang="ar" dir="rtl"><body>{children}</body></html>}
