# System Organizer - Guia de Compilação e Distribuição

## 🔧 Compilação do Projeto

### Pré-requisitos
- Xcode 14.0 ou superior
- macOS 13.0 ou superior
- Conta Apple Developer (para assinatura)

### Passos de Compilação

#### 1. Preparar o Projeto no Xcode

```bash
# Abrir o projeto
open SystemOrganizer.xcodeproj

# Ou criar um novo projeto
xcode-select --install
```

#### 2. Configurar Capacidades

No Xcode:
1. Selecione o target "SystemOrganizer"
2. Vá para "Signing & Capabilities"
3. Adicione as seguintes capacidades:
   - **iCloud** (CloudKit)
   - **Calendar** (EventKit)
   - **Contacts** (se necessário)

#### 3. Configurar Assinatura

1. Vá para "Signing & Capabilities"
2. Selecione sua equipe Apple Developer
3. Configure o Bundle ID (ex: `com.giovannini.systemorganizer`)

#### 4. Compilar para Release

```bash
# Compilação via linha de comando
xcodebuild -scheme SystemOrganizer \
  -configuration Release \
  -arch arm64 \
  build

# Ou via Xcode
# Product → Scheme → SystemOrganizer
# Product → Build for → Running
```

## 📦 Criação do App Bundle

### Método 1: Via Xcode

1. Selecione "Product" → "Archive"
2. Selecione o arquivo criado
3. Clique em "Distribute App"
4. Escolha "Direct Distribution"
5. Exporte o `.app`

### Método 2: Via Linha de Comando

```bash
# Criar o app bundle
xcodebuild -scheme SystemOrganizer \
  -configuration Release \
  -derivedDataPath build \
  build

# Localizar o app
find build -name "*.app" -type d
```

## 🔐 Assinatura de Código

### Assinar o App

```bash
# Assinar com certificado de desenvolvimento
codesign -s - /path/to/SystemOrganizer.app

# Assinar com certificado de distribuição
codesign -s "Developer ID Application" /path/to/SystemOrganizer.app

# Verificar assinatura
codesign -v /path/to/SystemOrganizer.app
```

### Notarização (Apple)

Para distribuição fora da App Store:

```bash
# 1. Criar um arquivo ZIP
ditto -c -k --sequesterRsrc /path/to/SystemOrganizer.app SystemOrganizer.zip

# 2. Enviar para notarização
xcrun notarytool submit SystemOrganizer.zip \
  --apple-id seu-email@example.com \
  --password seu-app-specific-password \
  --team-id XXXXXXXXXX

# 3. Aguardar aprovação (pode levar alguns minutos)

# 4. Grampear o ticket de notarização
xcrun stapler staple /path/to/SystemOrganizer.app
```

## 📱 Distribuição

### Opção 1: Distribuição Direta

1. Crie um arquivo DMG:
```bash
# Criar DMG
hdiutil create -volname "System Organizer" \
  -srcfolder /path/to/SystemOrganizer.app \
  -ov -format UDZO SystemOrganizer.dmg
```

2. Distribua o arquivo `.dmg` ou `.zip`

### Opção 2: App Store

1. Prepare o app conforme acima
2. Vá para App Store Connect
3. Crie uma nova versão
4. Upload do build
5. Envie para revisão

### Opção 3: GitHub Releases

```bash
# Criar release no GitHub
gh release create v1.0.0 \
  --title "System Organizer v1.0.0" \
  --notes "Primeira versão estável" \
  SystemOrganizer.dmg
```

## ✅ Testes Pré-Distribuição

### Checklist de Testes

- [ ] App inicia sem erros
- [ ] Todas as views carregam corretamente
- [ ] CloudKit sincroniza
- [ ] Automações executam
- [ ] SSH conecta a máquinas remotas
- [ ] Calendário carrega eventos
- [ ] Obsidian integra corretamente
- [ ] Menu bar funciona
- [ ] Notificações funcionam
- [ ] App fecha sem erros

### Teste de Performance

```bash
# Monitorar uso de memória
instruments -t "Allocations" /path/to/SystemOrganizer.app

# Monitorar CPU
instruments -t "System Trace" /path/to/SystemOrganizer.app
```

## 🐛 Troubleshooting de Compilação

### Erro: "Code signing required"
```bash
# Solução: Assinar manualmente
codesign -s - /path/to/SystemOrganizer.app
```

### Erro: "CloudKit not available"
- Verifique se CloudKit foi adicionado às capacidades
- Verifique se está logado no iCloud

### Erro: "Architecture not supported"
```bash
# Compilar para arquitetura correta
xcodebuild -scheme SystemOrganizer \
  -arch arm64 \
  build
```

## 📊 Versionamento

### Estrutura de Versão: MAJOR.MINOR.PATCH

- **MAJOR**: Mudanças significativas
- **MINOR**: Novas features
- **PATCH**: Bug fixes

### Atualizar Versão

1. Abra `Info.plist`
2. Atualize `CFBundleShortVersionString` (ex: 1.0.0)
3. Atualize `CFBundleVersion` (ex: 1)

## 🚀 Deploy Automático

### GitHub Actions

Crie `.github/workflows/build.yml`:

```yaml
name: Build System Organizer

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Build
        run: |
          xcodebuild -scheme SystemOrganizer \
            -configuration Release \
            -arch arm64 \
            build
      
      - name: Create DMG
        run: |
          hdiutil create -volname "System Organizer" \
            -srcfolder build/Release/SystemOrganizer.app \
            -ov -format UDZO SystemOrganizer.dmg
      
      - name: Upload Release
        uses: softprops/action-gh-release@v1
        with:
          files: SystemOrganizer.dmg
```

## 📝 Release Notes

### Template

```markdown
# System Organizer v1.0.0

## ✨ Novas Features
- Dashboard em tempo real
- Sincronização CloudKit
- Controle remoto SSH

## 🐛 Correções
- Corrigido erro de sincronização
- Melhorada performance do monitoramento

## 📦 Download
- [SystemOrganizer.dmg](link)
- [SystemOrganizer.zip](link)

## 🔐 Verificação
SHA256: xxxxx
```

## 📞 Suporte Pós-Distribuição

### Monitorar Crashes
1. Implemente Sentry ou Crashlytics
2. Configure relatórios de erro
3. Monitore feedback dos usuários

### Atualizações
1. Implemente verificação de atualização
2. Notifique usuários sobre novas versões
3. Forneça changelog detalhado

---

**Última atualização**: Fevereiro 26, 2025
