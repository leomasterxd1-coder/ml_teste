# Changelog

Todas as mudanças notáveis do minha-loja. O topo deste arquivo é publicado
automaticamente como nota (notes) no release/patch do Shorebird.

## [Não lançado]
- Fix: overlay do Promocional Editável no tamanho 1x1 volta a aparecer no PDF compartilhado (usa o fluxo raster com overlay PNG, igual à pré-visualização)
- Badge "leve e ganhe" mostra valor unitário (leve X por R$ Y | R$ Z valor unitário)
- Campo de busca limpo ao ganhar foco (código escaneado some para digitação manual)
- Login Microsoft mostra tela "Escolher uma conta" (contas salvas) para troca de conta
- Correção do patch OTA: verificação de token por cookie via JavaScript + lock restaurado (webview 4.14.1)
- Voltar/deslizar fecha o app sem deslogar (mantém sessão ativa)
- Marca d'água 'a' do login igual ao minhaloja-kotlin (cinza bem claro + subida)
- Diagnóstico do preview Comum (Modelo): logs do template enviado, status HTTP e tamanho do PDF retornado pela API (via logcat tag "MinhaLoja")
- "Comum (Modelo)": fluxo idêntico ao Comum Editável (template original da API + modoEditavel)
- Reverte fix do template no Comum (Modelo): agora fiel ao Kotlin, usa o template original da API (ex: comum_por)
- Modo Promocional removido das Papeletas (fica: Misto, Promocional Editável, Comum, Comum Editável, Vencimentos)
- Modo Comum agora abre preview de papeletas (igual ao Misto)
- Zoom por pinça no leitor de código de barras (mapeamento corrigido)
- Animação de exclusão por deslize mais rápida (700ms -> 300ms)

## [1.1.73+73] - 2026-09-21
- Integração Shorebird (OTA Code Push)
- Release sem obfuscate para permitir patches OTA
