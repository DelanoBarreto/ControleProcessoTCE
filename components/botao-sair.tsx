'use client'

import { useRouter } from 'next/navigation'

import { createBrowserSupabase } from '@/lib/supabase/client'

export function BotaoSair() {
  const router = useRouter()

  async function sair() {
    await createBrowserSupabase().auth.signOut()
    router.push('/login')
    router.refresh()
  }

  return (
    <button
      onClick={sair}
      className="rounded-md border border-slate-300 px-3 py-1.5 text-sm hover:bg-slate-100"
    >
      Sair
    </button>
  )
}
