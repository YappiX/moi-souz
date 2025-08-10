export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ru">
      <body style={{ maxWidth: 900, margin: '0 auto', padding: 24 }}>{children}</body>
    </html>
  );
}