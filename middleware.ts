import { NextResponse, type NextRequest } from 'next/server'
import { createServerClient, type CookieOptions } from '@supabase/ssr'

import { getPublishableKey, getSupabaseUrl, SISTEMA } from '@/lib/supabase/config'

type CookieParaDefinir = { name: string; value: string; options: CookieOptions }

const ROTAS_PROTEGIDAS = ['/admin', '/gestor', '/interno'] as const

/**
 * Renova a sessao e barra acesso nao autenticado.
 *
 * O middleware e a primeira barreira, nao a unica: a autorizacao real esta nas
 * policies de RLS do banco. Um usuario que burle esta checagem continua sem
 * enxergar dado de outro tenant, porque `auth.uid()` e o papel sao resolvidos
 * no Postgres. Ver docs/ARQUITETURA.md.
 */
export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request })

  const supabase = createServerClient(getSupabaseUrl(), getPublishableKey(), {
    cookies: {
      getAll() {
        return request.cookies.getAll()
      },
      setAll(cookiesToSet: CookieParaDefinir[]) {
        cookiesToSet.forEach(({ name, value }) => {
          request.cookies.set(name, value)
        })
        response = NextResponse.next({ request })
        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options)
        })
      },
    },
  })

  // getUser() revalida o token no servidor do Supabase. getSession() apenas le
  // o cookie, que o cliente pode forjar — por isso nao serve para autorizar.
  const { data: { user } } = await supabase.auth.getUser()

  const { pathname } = request.nextUrl
  const protegida = ROTAS_PROTEGIDAS.some(
    (rota) => pathname === rota || pathname.startsWith(`${rota}/`),
  )

  if (protegida && !user) {
    const login = request.nextUrl.clone()
    login.pathname = '/login'
    login.searchParams.set('redirect', pathname)
    return NextResponse.redirect(login)
  }

  // /interno exige papel de plataforma (superadmin), verificado no banco.
  // A policy de RLS ja negaria os dados; isto evita servir a casca da tela a
  // quem nao deveria sequer saber que ela existe.
  if (pathname.startsWith('/interno') && user) {
    const { data: ehPlataforma } = await supabase.rpc('eh_papel_de_plataforma', {
      p_sistema: SISTEMA,
    })

    if (!ehPlataforma) {
      return new NextResponse('Forbidden', { status: 403 })
    }
  }

  if (pathname === '/login' && user) {
    const destino = request.nextUrl.clone()
    destino.pathname = '/admin'
    destino.searchParams.delete('redirect')
    return NextResponse.redirect(destino)
  }

  return response
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'],
}
