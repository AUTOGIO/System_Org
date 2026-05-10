# 📦 System Organizer - Guia Completo de Instalação

Instruções passo a passo para instalar e configurar o System Organizer em seu Mac.

## 🔍 Verificar Requisitos

### Requisitos do Sistema

```bash
# Verificar versão do macOS
sw_vers

# Verificar Xcode
xcode-select --version

# Verificar Swift
swift --version
```

Você precisa de:
- **macOS 13.0 ou superior**
- **Xcode 14.0 ou superior**
- **Swift 5.9 ou superior**
- **Conta iCloud** (para CloudKit)

### Instalar Xcode (se necessário)

```bash
# Instalar Xcode Command Line Tools
xcode-select --install

# Ou instalar Xcode completo
# Vá para App Store e procure por "Xcode"
```

## 📥 Obter o Código-Fonte

### Opção 1: GitHub

```bash
# Clone o repositório
git clone https://github.com/seu-usuario/SystemOrganizer.git
cd SystemOrganizer

# Ou se já tiver o arquivo ZIP
unzip SystemOrganizer.zip
cd SystemOrganizer
```

### Opção 2: Arquivo Local

Se recebeu o projeto em um arquivo:

```bash
# Extrair o arquivo
unzip SystemOrganizer.zip

# Ou se for um arquivo tar
tar -xzf SystemOrganizer.tar.gz

# Entrar no diretório
cd SystemOrganizer
```

## 🛠️ Compilação do Projeto

### Método 1: Usando Xcode (Recomendado)

#### Passo 1: Abrir o Projeto

```bash
# Abrir o projeto no Xcode
open SystemOrganizer.xcodeproj

# Ou se estiver usando Swift Package Manager
open -a Xcode .
```

#### Passo 2: Configurar Capacidades

1. No Xcode, selecione o target **"SystemOrganizer"**
2. Vá para a aba **"Signing & Capabilities"**
3. Clique em **"+ Capability"**
4. Adicione as seguintes capacidades:
   - **iCloud** (para CloudKit)
   - **Calendar** (para EventKit)

#### Passo 3: Configurar Assinatura

1. Em **"Signing & Capabilities"**
2. Selecione sua equipe Apple Developer
3. Configure o Bundle ID (ex: `com.seu-usuario.systemorganizer`)

#### Passo 4: Compilar e Executar

```bash
# Via Xcode
# Pressione Cmd + R (ou clique em ▶️)

# Ou via linha de comando
xcodebuild -scheme SystemOrganizer -configuration Debug
```

### Método 2: Usando Linha de Comando

```bash
# Compilar o projeto
xcodebuild -scheme SystemOrganizer \
  -configuration Release \
  -arch arm64 \
  -derivedDataPath build

# Encontrar o app compilado
find build -name "SystemOrganizer.app" -type d

# Executar o app
open build/Release/SystemOrganizer.app
```

### Método 3: Usando Swift Package Manager

```bash
# Compilar com SPM
swift build -c release

# Executar
swift run SystemOrganizer
```

## ✅ Verificação Pós-Instalação

### Teste 1: Verificar Compilação

```bash
# Verificar se o app foi criado
ls -la /path/to/SystemOrganizer.app

# Verificar assinatura
codesign -v /path/to/SystemOrganizer.app
```

### Teste 2: Executar o App

1. Abra o Finder
2. Navegue até o arquivo `SystemOrganizer.app`
3. Clique duas vezes para executar
4. Autorize as permissões solicitadas

### Teste 3: Verificar CloudKit

Na primeira execução:
1. O app pedirá permissão para acessar iCloud
2. Clique "Allow"
3. Verifique se o status mostra "CloudKit Ready"

### Teste 4: Verificar Calendário

1. Vá para a aba "Calendar"
2. Selecione uma data
3. Verifique se os eventos aparecem

## 🔐 Configuração de Segurança

### Permitir Execução do App

Se receber aviso de "aplicativo não verificado":

```bash
# Remover quarentena
xattr -d com.apple.quarantine /path/to/SystemOrganizer.app

# Ou abrir com Ctrl + clique
# Selecione "Open" na caixa de diálogo
```

### Configurar Permissões

O app solicitará permissão para:

1. **iCloud/CloudKit**: Clique "Allow"
2. **Calendário**: Clique "Allow"
3. **Notificações**: Clique "Allow"
4. **Acesso ao Disco**: Clique "Allow"

### SSH Key Setup

Para usar controle remoto SSH:

```bash
# Verificar se já tem chave SSH
ls -la ~/.ssh/id_ed25519

# Se não tiver, criar nova chave
ssh-keygen -t ed25519 -C "seu-email@example.com"

# Copiar chave pública para servidor remoto
ssh-copy-id -i ~/.ssh/id_ed25519.pub usuario@servidor
```

## 📍 Instalação Permanente

### Opção 1: Copiar para Applications

```bash
# Copiar o app para Applications
cp -r /path/to/SystemOrganizer.app /Applications/

# Ou via Finder
# Arraste SystemOrganizer.app para a pasta Applications
```

### Opção 2: Criar Alias na Barra de Menu

1. Abra o Finder
2. Vá para Applications
3. Clique com botão direito em SystemOrganizer.app
4. Selecione "Add to Dock"

### Opção 3: Executar na Inicialização

1. Abra System Preferences
2. Vá para "General" → "Login Items"
3. Clique "+"
4. Selecione SystemOrganizer.app
5. Clique "Add"

## 🔄 Atualizar o App

### Atualizar do Código-Fonte

```bash
# Entrar no diretório
cd SystemOrganizer

# Atualizar do repositório
git pull origin main

# Recompilar
xcodebuild -scheme SystemOrganizer -configuration Release
```

### Atualizar Dependências

```bash
# Se usar Cocoapods
pod update

# Se usar SPM
swift package update
```

## 🐛 Troubleshooting de Instalação

### Erro: "Xcode not found"

```bash
# Instalar Xcode Command Line Tools
xcode-select --install

# Ou configurar o caminho do Xcode
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### Erro: "Code signing required"

```bash
# Assinar o app manualmente
codesign -s - /path/to/SystemOrganizer.app

# Ou remover a assinatura existente
codesign --remove-signature /path/to/SystemOrganizer.app
```

### Erro: "CloudKit not available"

1. Verifique se está logado no iCloud:
   ```bash
   dscl . -read /Users/$(whoami) AppleMetaNodeLocation
   ```

2. Se não estiver logado, vá para:
   - System Preferences → iCloud
   - Faça login com sua conta Apple

3. Ative iCloud Drive:
   - System Preferences → iCloud
   - Marque "iCloud Drive"

### Erro: "Permission denied"

```bash
# Dar permissão de execução
chmod +x /path/to/SystemOrganizer.app/Contents/MacOS/SystemOrganizer

# Ou remover quarentena
xattr -d com.apple.quarantine /path/to/SystemOrganizer.app
```

### Erro: "Architecture mismatch"

```bash
# Verificar arquitetura do Mac
uname -m

# Se for Apple Silicon (M1/M2/M3):
# arm64 é correto

# Se for Intel:
# x86_64 é correto

# Compilar para arquitetura correta
xcodebuild -scheme SystemOrganizer \
  -arch arm64 \
  build
```

## 📊 Verificar Instalação

### Checklist Final

- [ ] Xcode instalado e atualizado
- [ ] Projeto compila sem erros
- [ ] App executa sem crashes
- [ ] CloudKit conecta com sucesso
- [ ] Calendário carrega eventos
- [ ] Automações aparecem
- [ ] Menu bar funciona
- [ ] SSH pode ser configurado

### Teste de Funcionalidade

```bash
# Executar com logs detalhados
SYSTEM_ORGANIZER_DEBUG=1 /Applications/SystemOrganizer.app/Contents/MacOS/SystemOrganizer

# Ou via Xcode
# Product → Scheme → Edit Scheme
# Run → Arguments → Adicione variável de ambiente
```

## 🚀 Próximos Passos

Após a instalação bem-sucedida:

1. Leia o **QUICKSTART.md** para começar
2. Configure suas automações
3. Adicione máquinas remotas
4. Configure CloudKit
5. Personalize as configurações

## 📞 Suporte de Instalação

Se encontrar problemas:

1. Verifique todos os requisitos
2. Consulte a seção Troubleshooting
3. Verifique os logs do Xcode
4. Tente recompilar do zero
5. Reinicie o Mac

## 🔗 Recursos Úteis

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI Documentation](https://developer.apple.com/xcode/swiftui/)
- [CloudKit Documentation](https://developer.apple.com/cloudkit/)
- [Xcode Help](https://help.apple.com/xcode/)

---

**Versão**: 1.0.0  
**Última atualização**: Fevereiro 26, 2025

**Sucesso na instalação! 🎉**
