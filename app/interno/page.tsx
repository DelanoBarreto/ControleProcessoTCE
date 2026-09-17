import { redirect } from 'next/navigation'

import { Cabecalho } from '@/components/cabecalho'
import { getContexto } from '@/lib/auth/contexto'
import { createServerSupabase } from '@/lib/supabase/server'

export default async function InternoPage() {
  const contexto = await getContexto()
  if (!contexto) redirect('/login?redirect=/interno')

  // Dupla checagem: o middleware ja barra, mas a pagina nao deve depender dele.
  // Se um dia o matcher mudar e deixar /interno de fora, aqui continua fechado.
  if (!contexto.eh_plataforma) redirect('/admin')

  const supabase = createServerSupabase()

  const [{ count: municipios }, { count: processos }] = await Promise.all([
    supabase.from('municipios').select('*', { count: 'exact', head: true }).eq('ativo', true),
    supabase.from('processos').select('*', { count: 'exact', head: true }),
  ])

  return (
    <>
      <Cabecalho contexto={contexto} area="Console interno" />

      <main className="mx-auto max-w-5xl px-6 py-8">
        <dl className="grid gap-4 sm:grid-cols-3">
          <div className="rounded-lg border border-slate-200 bg-white p-5">
            <dt className="text-sm text-slate-600">Municípios ativos</dt>
            <dd className="mt-1 text-2xl font-semibold">{municipios ?? 0}</dd>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-5">
            <dt className="text-sm text-slate-600">Processos coletados</dt>
            <dd className="mt-1 text-2xl font-semibold">{processos ?? 0}</dd>
          </div>
        </dl>

        <p className="mt-8 text-sm text-slate-600">
          A ingestão e o inspetor de sincronização chegam na Fase 2.
        </p>
      </main>
    </>
  )
}
