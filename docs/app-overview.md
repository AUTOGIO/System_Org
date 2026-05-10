# System Organizer - macOS Native Application

Uma aplicação macOS nativa completa em Swift/SwiftUI que consolida todas as automações do sistema, oferecendo um painel de controle interativo com sincronização CloudKit.

## 🎯 Visão Geral

**System Organizer** é uma ferramenta profissional de automação para macOS que integra:

- **Dashboard em Tempo Real**: Monitoramento de CPU, Memória e Disco
- **Gerenciador de Automações**: Controle centralizado de todos os scripts
- **Sincronização CloudKit**: Backup automático de configurações
- **Controle Remoto SSH**: Gerenciamento de máquinas remotas
- **Integração com Calendário**: Visualização de eventos do dia
- **Integração com Obsidian**: Gerenciamento de vaults e notas
- **Menu Bar**: Acesso rápido às funções principais
- **Monitoramento Contínuo**: Gráficos em tempo real de performance

## 📋 Requisitos

- **macOS 13.0+**
- **Xcode 14.0+**
- **Apple Silicon ou Intel (otimizado para M-series)**
- **iCloud Account** (para CloudKit)

## 🚀 Instalação e Compilação

### 1. Clone o Repositório
```bash
git clone <repository-url>
cd SystemOrganizer
```

### 2. Abra no Xcode
```bash
open SystemOrganizer.xcodeproj
```

### 3. Configure o CloudKit
- Abra o projeto no Xcode
- Selecione o target "SystemOrganizer"
- Vá para "Signing & Capabilities"
- Clique em "+ Capability"
- Adicione "iCloud" e selecione "CloudKit"

### 4. Compile e Execute
```bash
# Via linha de comando
xcodebuild -scheme SystemOrganizer -configuration Release

# Ou use Xcode (Cmd + R)
```

## 📁 Estrutura do Projeto

```
SystemOrganizer/
├── Sources/
│   ├── SystemOrganizerApp.swift          # Entry point
│   ├── Managers/
│   │   ├── AutomationManager.swift       # Gerenciamento de automações
│   │   ├── CloudKitManager.swift         # Sincronização CloudKit
│   │   └── MonitoringManager.swift       # Monitoramento do sistema
│   ├── Models/
│   │   └── AutomationModel.swift         # Modelos de dados
│   └── Views/
│       ├── ContentView.swift             # View principal
│       ├── DashboardView.swift           # Dashboard
│       ├── AutomationsView.swift         # Gerenciador de automações
│       ├── MonitoringView.swift          # Monitoramento
│       ├── RemoteControlView.swift       # Controle remoto SSH
│       ├── CalendarView.swift            # Integração com calendário
│       ├── ObsidianView.swift            # Integração com Obsidian
│       ├── SettingsView.swift            # Configurações
│       └── MenuBarView.swift             # Menu bar
├── Package.swift                         # Definição do package
└── README.md                             # Este arquivo
```

## 🎨 Funcionalidades Principais

### 1. Dashboard
- Visualização em tempo real de CPU, Memória e Disco
- Lista de automações ativas
- Histórico de atividades recentes
- Status de sincronização CloudKit

### 2. Gerenciador de Automações
- Ativar/desativar automações individuais
- Executar scripts manualmente
- Visualizar logs de execução
- Filtrar por categoria
- Busca em tempo real

### 3. Monitoramento
- Gráficos em tempo real (CPU, Memória, Disco)
- Informações do sistema
- Histórico de performance
- Alertas de uso excessivo

### 4. Controle Remoto
- Gerenciar múltiplas máquinas SSH
- Verificar status de conexão
- Executar comandos remotos
- Adicionar/remover máquinas

### 5. Calendário
- Visualizar eventos do dia
- Filtrar por data
- Ver detalhes de eventos
- Integração com Calendário do macOS

### 6. Obsidian
- Gerenciar múltiplos vaults
- Criar notas
- Listar arquivos
- Sincronizar com vaults locais

### 7. Menu Bar
- Acesso rápido às automações
- Status do sistema
- Sincronização CloudKit
- Atalhos para ações comuns

## ⚙️ Configuração de Automações

### Adicionar Nova Automação

1. Vá para a aba "Automations"
2. Clique no botão "+"
3. Preencha os campos:
   - **Nome**: Nome descritivo
   - **Descrição**: O que faz
   - **Caminho do Script**: Caminho completo do script
   - **Agendamento**: Manual, Horário, Diário, Semanal
   - **Categoria**: Classificação
   - **Tags**: Palavras-chave

### Automações Pré-configuradas

O app vem com as seguintes automações:

1. **Calendar Summary** - Envia resumo diário de eventos por e-mail
2. **Organize Desktop** - Organiza arquivos da área de trabalho
3. **Save to Obsidian** - Salva mensagens no Obsidian
4. **Restore Spaces** - Restaura configuração de workspaces
5. **Terminal Tasks** - Executa tarefas de terminal
6. **SDK Agent Setup** - Configura agente Streamlit

## 🔐 Segurança e Privacidade

- **Dados Locais**: Todas as configurações são armazenadas localmente
- **CloudKit**: Sincronização criptografada via iCloud
- **SSH**: Chaves Ed25519 para conexões remotas
- **Permissões**: Solicita acesso apenas quando necessário

## 📊 Monitoramento de Performance

O app monitora continuamente:

- **CPU Usage**: Percentual de utilização
- **Memory Usage**: RAM utilizada
- **Disk Usage**: Espaço em disco
- **System Uptime**: Tempo desde o último reinício
- **Process Count**: Número de processos ativos

## 🔄 Sincronização CloudKit

### Como Funciona

1. Configurações são salvas localmente
2. CloudKit sincroniza automaticamente a cada 5 minutos
3. Alterações em outro dispositivo são baixadas
4. Conflitos são resolvidos automaticamente

### Configurar CloudKit

```swift
// Em CloudKitManager.swift
let container = CKContainer.default()
container.accountStatus { status, error in
    // Verificar status da conta iCloud
}
```

## 🐛 Troubleshooting

### CloudKit não funciona
- Verifique se está logado no iCloud
- Verifique as capacidades do projeto
- Reinicie o app

### Automações não executam
- Verifique o caminho do script
- Verifique permissões do arquivo
- Veja os logs de execução

### SSH não conecta
- Verifique o hostname/IP
- Verifique credenciais SSH
- Teste com `ssh user@host` no terminal

## 📝 Logs e Debugging

### Visualizar Logs
1. Vá para a automação
2. Clique no botão "Logs"
3. Veja o histórico de execução

### Console do Xcode
```bash
# Executar com logs detalhados
xcodebuild -scheme SystemOrganizer -configuration Debug -verbose
```

## 🎯 Próximas Melhorias

- [ ] Agendamento visual com calendário
- [ ] Notificações push
- [ ] Suporte a webhooks
- [ ] Histórico de performance detalhado
- [ ] Exportar relatórios
- [ ] Integração com Slack
- [ ] Backup automático
- [ ] Modo escuro aprimorado

## 📄 Licença

Propriedade privada - Giovannini Mare Capital LLC

## 👨‍💻 Desenvolvimento

### Requisitos de Desenvolvimento
- Swift 5.9+
- SwiftUI
- CloudKit
- EventKit (Calendário)

### Estrutura de Código

O projeto segue a arquitetura MVVM:

- **Models**: Estruturas de dados (AutomationModel, RemoteMachine, etc.)
- **ViewModels**: Managers (AutomationManager, CloudKitManager, etc.)
- **Views**: Interface SwiftUI

### Adicionar Nova Feature

1. Crie um novo Manager em `Managers/`
2. Crie uma nova View em `Views/`
3. Integre no ContentView
4. Adicione ao TabView

## 🤝 Suporte

Para suporte ou reportar bugs:
1. Verifique a seção Troubleshooting
2. Consulte os logs do app
3. Reinicie o app

## 📞 Contato

**Desenvolvedor**: Manus AI  
**Data de Criação**: Fevereiro 26, 2025  
**Versão**: 1.0.0

---

**Desenvolvido com ❤️ para macOS**
