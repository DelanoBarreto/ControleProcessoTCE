import 'server-only'

import { createServerSupabase } from '@/lib/supabase/server'

export type ContextoUsuario = {
  usuario_sistema_id: string
  nome: string
  papel: string | null
  is_suporte: boolean
  eh_plataforma: boolean
  organizacao_id: string | null
  organizacao_nome: string | null
  organizacao_slug: string | null
}

/**
 * Contexto do usuario logado, resolvido pelo banco.
 *
 * Retorna null se nao ha sessao, ou se a conta autenticou mas nao tem vinculo
 * ativo com o sistema TCE — ter login no Supabase nao e o mesmo que ter acesso
 * a este sistema.
 */
export async function getContexto(tenantSlug?: string): Promise<ContextoUsuario | null> {
  const supabase = createServerSupabase(tenantSlug)

  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return null

  const { data } = await supabase.rpc('meu_contexto').single<ContextoUsuario>()
  return data ?? null
}
