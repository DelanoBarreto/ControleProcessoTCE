import { LoginForm } from './login-form'

export default function LoginPage({
  searchParams,
}: {
  searchParams: { redirect?: string }
}) {
  return (
    <main className="mx-auto flex min-h-screen max-w-sm flex-col justify-center px-6">
      <h1 className="text-2xl font-semibold tracking-tight">Entrar</h1>
      <p className="mt-1 text-sm text-slate-600">Plataforma TCE</p>

      <LoginForm redirectTo={searchParams.redirect} />
    </main>
  )
}
