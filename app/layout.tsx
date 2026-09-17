import type { Metadata } from 'next'

import './globals.css'

export const metadata: Metadata = {
  title: 'Plataforma TCE',
  description: 'Monitoramento de processos do Tribunal de Contas do Estado do Ceará',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  )
}
