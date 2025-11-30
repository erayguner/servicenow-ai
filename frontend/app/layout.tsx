import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'AI Research Assistant',
  description: 'Internal AI Research Assistant with conversational interface',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
