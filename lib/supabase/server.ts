import 'server-only'

import { cookies } from 'next/headers'
import { createServerClient, type CookieOptions } from '@supabase/ssr'
import { createClient } from '@supabase/supabase-js'

type CookieParaDefinir = { name: string; value: string; options: CookieOptions }

import { getPublishableKey, getSecretKey, getSupabaseUrl, TENANT_HEADER } from './config'

/**
 * Cliente para requisicoes de usuario autenticado.
 *
 * Usa o JWT da sessao, entao `auth.uid()` existe no Postgres e a RLS funciona.
 * E este o cliente que serve dados de tenant — nunca o de service role.
 *
 * @param tenantSlug slug da organizacao pedida; vira o header que
 *   plataforma.org_pedida() le para resolver o tenant. Sem ele, as funcoes
 *   org_atual()/papel_atual() retornam NULL e a RLS nega tudo, exceto para
 *   papel de plataforma.
 */
export function createServerSupabase(tenantSlug?: string) {
  const cookieStore = cookies()

  return createServerClient(getSupabaseUrl(), getPublishableKey(), {
    cookies: {
      getAll() {
        return cookieStore.getAll()
      },
      setAll(cookiesToSet: CookieParaDefinir[]) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => {
            cookieStore.set(name, value, options)
          })
        } catch {
          // Server Component nao pode escrever cookie. O middleware ja
          // renovou a sessao, entao ignorar aqui e seguro.
        }
      },
    },
    global: tenantSlug
      ? { headers: { [TENANT_HEADER]: tenantSlug } }
      : undefined,
    db: { schema: 'tce' },
  })
}

/**
 * Cliente administrativo. IGNORA RLS.
 *
 * Restrito a rotas de API e tarefas internas — nunca para servir dado a um
 * usuario autenticado, porque a RLS deixa de valer e o isolamento multi-tenant
 * inteiro depende dela.
 *
 * Para a ingestao do TCE, prefira a role dedicada `tce_ingestor` (conexao
 * Postgres direta): a chave secreta alcanca qualquer schema do projeto,
 * inclusive os de outros sistemas hospedados no mesmo banco.
 */
export function createAdminSupabase(schema: 'tce' | 'plataforma' = 'tce') {
  return createClient(getSupabaseUrl(), getSecretKey(), {
    auth: { persistSession: false, autoRefreshToken: false },
    db: { schema },
  })
}
