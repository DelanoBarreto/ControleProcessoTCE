/**
 * Leitura e validacao das variaveis de ambiente do Supabase.
 *
 * Aceita a nomenclatura nova (publishable/secret) e a legada
 * (anon/service_role) como fallback: projetos criados antes da mudanca do
 * Supabase ainda usam os nomes antigos, e um deploy nao deve quebrar so por
 * causa disso.
 */

export function getSupabaseUrl(): string {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  if (!url) {
    throw new Error('NEXT_PUBLIC_SUPABASE_URL nao configurada')
  }
  return url
}

/** Chave publica, protegida por RLS. Pode ir para o browser. */
export function getPublishableKey(): string {
  const key =
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  if (!key) {
    throw new Error(
      'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY (ou a legada NEXT_PUBLIC_SUPABASE_ANON_KEY) nao configurada',
    )
  }
  return key
}

/**
 * Chave secreta. IGNORA RLS.
 *
 * Lanca se chamada fora do servidor: importar este caminho em componente de
 * cliente e o erro que vaza a chave para o bundle do browser.
 */
export function getSecretKey(): string {
  if (typeof window !== 'undefined') {
    throw new Error('getSecretKey() chamada no browser — a chave secreta nunca pode sair do servidor')
  }

  const key =
    process.env.SUPABASE_SECRET_KEY ??
    process.env.SUPABASE_SERVICE_ROLE_KEY

  if (!key) {
    throw new Error(
      'SUPABASE_SECRET_KEY (ou a legada SUPABASE_SERVICE_ROLE_KEY) nao configurada',
    )
  }
  return key
}

/** Sistema deste app dentro do schema `plataforma`. */
export const SISTEMA = 'tce' as const

/** Header lido por plataforma.org_pedida() para resolver o tenant. */
export const TENANT_HEADER = 'x-tenant-slug'
