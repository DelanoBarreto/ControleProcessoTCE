import { redirect } from 'next/navigation'

import { Cabecalho } from '@/components/cabecalho'
import { getContexto } from '@/lib/auth/contexto'
import { createServerSupabase } from '@/lib/supabase/server'

export default async function GestorPage() {
  const contexto = await getContexto()
  if (!contexto) redirect('/login?redirect=/gestor')

  const supabase = createServerSupabase(contexto.organizacao_slug ?? undefined)

  // O gestor so enxerga os processos vinculados ao cliente que e ele proprio.
  // Essa restricao esta DENTRO da policy de SELECT de processos_monitorados,
  // nao aqui: uma policy separada para o gestor somaria acesso via OR em vez
  // de restringir. Ver docs/MODELAGEM_DADOS.md.
  const { count } = await supabase
    .from('processos_monitorados')
    .select('*', { count: 'exact', head: true })

  return (
    <>
      <Cabecalho contexto={contexto} area="Meus processos" />

      <main className="mx-auto max-w-5xl px-6 py-8">
        <div className="rounded-lg border border-slate-200 bg-white p-5">
          <p className="text-sm text-slate-600">Processos acompanhados</p>
          <p className="mt-1 text-2xl font-semibold">{count ?? 0}</p>
        </div>

        <p className="mt-8 text-sm text-slate-600">
          O acompanhamento detalhado e a aprovação de peças chegam na Fase 5.
        </p>
      </main>
    </>
  )
}
