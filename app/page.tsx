import Link from 'next/link'

export default function Home() {
  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col justify-center gap-6 px-6">
      <div>
        <h1 className="text-3xl font-semibold tracking-tight">Plataforma TCE</h1>
        <p className="mt-2 text-slate-600">
          Monitoramento de processos do Tribunal de Contas do Estado do Ceará.
        </p>
      </div>

      <Link
        href="/login"
        className="w-fit rounded-md bg-slate-900 px-5 py-2.5 text-sm font-medium text-white hover:bg-slate-700"
      >
        Entrar
      </Link>
    </main>
  )
}
