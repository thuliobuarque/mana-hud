# Mana HUD 🎮

Painel gamer para acompanhar recursos de IA. Criado a partir da HUD·IA de Thulio Buarque e alimentado pelo projeto independente [ai-usagebar](https://github.com/akitaonrails/ai-usagebar).

## Como funciona

HP, MP e SP representam as janelas de limite recebidas do provedor, em ordem. A barra mostra o percentual restante. O contador de reset depende do horário informado pelo provedor; zerar o relógio não garante atualização imediata.

O painel Windows para Codex consulta os dados a cada 3 minutos e atualiza o relógio a cada segundo. O painel experimental do Claude consulta a cada 5 minutos; a tecla `r` força nova consulta. A animação não faz consultas.

## Começar

Instale e configure o [ai-usagebar](https://github.com/akitaonrails/ai-usagebar) e confirme que `ai-usagebar usage --json` funciona. Nunca salve credenciais neste repositório.

No Windows, o arquivo `codex-hud.ps1` abre uma janela separada. O arquivo original pressupõe a instalação do ai-usagebar em `%LOCALAPPDATA%\Programs\ai-usagebar`. `session-start.ps1` captura a base de economia do RTK e abre a janela; seu caminho está fixo no computador de origem e precisa de ajuste. A integração por hook SessionStart depende de configuração e aprovação no Codex.

O painel de Claude no arquivo `painel-claude.zip` (extraia na pasta do projeto) usa APIs experimentais de interface, abre em `session.start`, aceita `/hud-ia`, teclas 1 a 7 e `r`. Requer um host compatível. O código possui configurações específicas do ambiente original.

## Limitações

O painel Codex usa Windows Forms e não funciona no macOS. O painel Claude não foi validado no Mac e contém comandos específicos de Windows. A ativação automática em sessões novas depende da configuração do host e ainda precisa de teste real. O ai-usagebar tem suporte próprio ao macOS, mas isso não implica suporte desta HUD.

RTK é opcional. A economia apresentada usa totais locais e uma base compartilhada entre sessões, não uma medição isolada de cada conversa. A presença de uma skill não prova que ela esteja ativa.

O ai-usagebar é uma dependência independente e mantém sua própria licença e autoria.
