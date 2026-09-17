import type { ContextoUsuario } from '@/lib/auth/contexto'

import { BotaoSair } from './botao-sair'

export function Cabecalho({ contexto, area }: { contexto: ContextoUsuario; area: string }) {
  return (
    <header className="border-b border-slate-200 bg-white">
      <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-3 px-6 py-4">
        <div>
          <p className="text-sm font-semibold">{area}</p>
          <p className="text-sm text-slate-600">
            {contexto.nome}
            {contexto.organizacao_nome && ` · ${contexto.organizacao_nome}`}
          </p>
        </div>
        <BotaoSair />
      </div>
    </header>
  )
}
