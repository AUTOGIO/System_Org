# 🚀 Quick Start Guide - System Organizer

Guia rápido para começar a usar o System Organizer em 5 minutos.

## ⚡ Primeiros Passos

### 1. Abrir o App

Após compilar e executar, o app abrirá com:
- Uma janela principal com 7 abas
- Um ícone na barra de menu (topo da tela)

### 2. Primeira Execução

Na primeira vez que abrir:
1. O app verificará a conta iCloud
2. Carregará as automações pré-configuradas
3. Iniciará o monitoramento do sistema

## 📊 Dashboard

A primeira aba mostra:

```
┌─────────────────────────────────┐
│ CPU: 25%  │ Memory: 45%  │ Disk: 60% │
├─────────────────────────────────┤
│ Active Automations (5 enabled)  │
│ • Calendar Summary - Daily 9am  │
│ • Organize Desktop - Daily 6pm  │
│ • Terminal Tasks - Daily 12am   │
├─────────────────────────────────┤
│ Recent Activity                 │
│ ✓ Calendar Summary - 14:30      │
│ ✓ Organize Desktop - 18:00      │
└─────────────────────────────────┘
```

## 🎯 Tarefas Comuns

### Executar uma Automação Manualmente

1. Vá para a aba **"Automations"**
2. Encontre a automação desejada
3. Clique no botão ▶️ (play)
4. Veja o status em tempo real

### Ativar/Desativar Automação

1. Na aba **"Automations"**
2. Clique no toggle ao lado do nome
3. A automação será ativada/desativada

### Ver Logs de Execução

1. Clique em uma automação
2. Clique no botão 📋 (logs)
3. Veja o histórico de execução

### Conectar a uma Máquina Remota

1. Vá para **"Remote"**
2. Clique em "+" para adicionar máquina
3. Preencha:
   - **Machine Name**: MacBook Air
   - **Hostname**: 192.168.1.154
   - **Username**: seu_usuario
   - **Port**: 22
4. Clique "Add"
5. Clique no botão de refresh para testar conexão

### Executar Comando Remoto

1. Na máquina remota, clique 🖥️ (terminal)
2. Digite o comando (ex: `ls -la`)
3. Clique ↩️ para executar
4. Veja o resultado

### Visualizar Eventos do Calendário

1. Vá para **"Calendar"**
2. Selecione uma data
3. Veja os eventos do dia
4. Clique em um evento para detalhes

### Criar Nota no Obsidian

1. Vá para **"Obsidian"**
2. Selecione um vault na esquerda
3. Clique "+" para nova nota
4. Digite título e conteúdo
5. Clique "Save"

## 🔧 Configurações Essenciais

### Ativar Notificações

1. Vá para **"Settings"**
2. Ative "Enable Notifications"
3. Você receberá alertas de automações

### Configurar Sincronização CloudKit

1. Em **"Settings"** → **"CloudKit Sync"**
2. Verifique o status (deve estar "CloudKit Ready")
3. Ajuste intervalo de sincronização se necessário
4. Clique "Sync Now" para sincronizar manualmente

### Configurar Retenção de Logs

1. Em **"Settings"** → **"Automations"**
2. Ajuste "Log Retention" (padrão: 100 entradas)
3. Logs antigos serão removidos automaticamente

## 📱 Menu Bar

Clique no ícone na barra de menu para:

```
┌──────────────────────────┐
│ System Status            │
│ CPU: 25%  Memory: 45%   │
│ Disk: 60%               │
├──────────────────────────┤
│ Quick Actions            │
│ ▶ Calendar Summary      │
│ ▶ Organize Desktop      │
│ ▶ Terminal Tasks        │
├──────────────────────────┤
│ ◉ CloudKit Ready        │
├──────────────────────────┤
│ Open Main Window         │
│ Quit                     │
└──────────────────────────┘
```

## 🎨 Dicas e Truques

### Buscar Automações

1. Na aba **"Automations"**
2. Digite no campo de busca
3. Filtre por categoria

### Visualizar Gráficos de Performance

1. Vá para **"Monitor"**
2. Veja gráficos em tempo real de:
   - CPU Usage
   - Memory Usage
   - Disk Usage

### Adicionar Múltiplas Máquinas Remotas

Você pode gerenciar várias máquinas:
- iMac
- MacBook Air
- Servidor Linux
- Qualquer máquina com SSH

### Agendamento de Automações

Opções disponíveis:
- **Manual**: Executar sob demanda
- **Hourly**: A cada hora
- **Daily 9am**: Todos os dias às 9h
- **Daily 6pm**: Todos os dias às 18h
- **Daily Midnight**: Todos os dias à meia-noite
- **Weekly**: Uma vez por semana

## ⚠️ Problemas Comuns

### "CloudKit not available"
- Verifique se está logado no iCloud
- Vá para System Preferences → iCloud
- Ative iCloud Drive

### "SSH connection failed"
- Verifique o hostname/IP
- Teste no terminal: `ssh user@host`
- Verifique firewall

### "Automation didn't run"
- Verifique se está ativada (toggle ON)
- Verifique o caminho do script
- Veja os logs para erros

### "App is slow"
- Reduza a frequência de sincronização
- Reduza o número de logs retidos
- Reinicie o app

## 📚 Próximos Passos

1. **Explorar todas as abas**: Dedique tempo para conhecer cada seção
2. **Configurar SSH**: Adicione suas máquinas remotas
3. **Personalizar automações**: Ajuste agendamentos conforme necessário
4. **Ativar notificações**: Receba alertas de eventos importantes
5. **Sincronizar CloudKit**: Garanta backup de configurações

## 🆘 Obter Ajuda

### Dentro do App
- Vá para **"Settings"**
- Veja "System Information"
- Copie informações para suporte

### Verificar Logs
- Abra o Console.app
- Procure por "SystemOrganizer"
- Veja mensagens de erro detalhadas

### Reiniciar o App
```bash
# Feche o app
# Reabra-o

# Ou via terminal
pkill SystemOrganizer
open /Applications/SystemOrganizer.app
```

## 🎓 Tutoriais Recomendados

1. **Dashboard**: Entenda as métricas do sistema
2. **Automações**: Crie sua primeira automação personalizada
3. **SSH**: Configure acesso a máquinas remotas
4. **CloudKit**: Sincronize com outro Mac

## 📞 Suporte

Se encontrar problemas:

1. Verifique este guia
2. Consulte o README.md
3. Veja os logs do app
4. Reinicie o app
5. Reinicie o Mac

---

**Versão**: 1.0.0  
**Última atualização**: Fevereiro 26, 2025

**Divirta-se automatizando seu Mac! 🚀**
