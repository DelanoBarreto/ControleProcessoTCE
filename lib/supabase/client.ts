'use client'

import { createBrowserClient } from '@supabase/ssr'

import { getPublishableKey, getSupabaseUrl, TENANT_HEADER } from './config'

/**
 * Cliente do browser. So a chave publica, sempre sujeito a RLS.
 *
 * Serve para login/logout e leitura. Escrita de dado de negocio passa por rota
 * de API que valida a sessao (rule-01): o frontend nao escreve direto no banco.
 */
export function createBrowserSupabase(tenantSlug?: string) {
  return createBrowserClient(getSupabaseUrl(), getPublishableKey(), {
    global: tenantSlug
      ? { headers: { [TENANT_HEADER]: tenantSlug } }
      : undefined,
    db: { schema: 'tce' },
  })
}
