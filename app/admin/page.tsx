import { redirect } from 'next/navigation'

import { Cabecalho } from '@/components/cabecalho'
import { getContexto } from '@/lib/auth/contexto'
import { createServerSupabase } from '@/lib/supabase/server'

export default async function AdminPage() {
  const contexto = await getContexto()
  if (!contexto) redirect('/login?redirect=/admin')

  // Gestor publico tem painel proprio, com visao restrita aos processos dele.
  if (contexto.papel === 'gestor_publico') redirect('/gestor')

  const supabase = createServerSupabase(contexto.organizacao_slug ?? undefined)

  // A contagem ja passa pela RLS: se vier 0 para um escritorio que tem
  // processos, o problema e de policy, nao de dado.
  const { count } = await supabase
    .from('processos_monitorados')
    .select('*', { count: 'exact', head: true })

  return (
    <>
      <Cabecalho contexto={contexto} area="Painel do escritório" />

      <main className="mx-auto max-w-5xl px-6 py-8">
        <dl className="grid gap-4 sm:grid-cols-3">
          <div className="rounded-lg border border-slate-200 bg-white p-5">
            <dt className="text-sm text-slate-600">Processos monitorados</dt>
            <dd className="mt-1 text-2xl font-semibold">{count ?? 0}</dd>
          </div>
        </dl>

        <p className="mt-8 text-sm text-slate-600">
          A listagem de processos, clientes e prazos chega na Fase 4.
        </p>
      </main>
    </>
  )
}
