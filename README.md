# OpenCode no Termux

Instala o [OpenCode](https://opencode.ai) no seu celular Android, usando o app **Termux**. Você pode escolher entre a versão **v1** (estável) e a **v2** (beta). Não precisa entender de programação: é só copiar e colar comandos.

## O que você precisa

- Um celular Android com o app **Termux** instalado (baixe pela loja **F-Droid**, não pela Play Store, que está desatualizada).
- Internet (Wi-Fi de preferência, o download é grande).
- Uns 2 GB livres no celular.
- 10 a 20 minutos de paciência na primeira vez.

## Instalação (passo a passo)

**1.** Abra o Termux e instale o `curl` (programa que baixa arquivos):

```sh
pkg install -y curl
```

**2.** Baixe o instalador:

```sh
curl -fsSL https://raw.githubusercontent.com/Lumikinho/termux-opencode/termux/opencode/install.sh -o install.sh
```

**3.** Rode o instalador:

```sh
bash install.sh
```

**4.** O script pergunta **qual versão** instalar. Digite `1` (versão estável) ou `2` (versão nova, em testes) e aperte Enter.

**5.** O script pede para **criar uma senha** (digite duas vezes igual). Essa senha protege o OpenCode no seu celular. Guarde-a.

**6.** O script pergunta se quer **cópia no armazenamento do dispositivo** (digite `s` para sim, Enter para não). Isso copia a configuração para `/sdcard/opencode`, que sobrevive mesmo se o Termux for apagado — mas atenção: nessa pasta outros apps podem ler os arquivos, inclusive a senha.

**7.** Aguarde. O script mostra uma lista de tarefas com 6 etapas (7 se ativou a cópia). No fim aparece:

```
Pronto! Comando instalado: opencode (opencode v1)
```

**8.** Use o OpenCode:

```sh
opencode
```

Se instalou a v2, a interface web abre com:

```sh
opencode pair
```

## Já instalei antes, e agora?

Pode rodar o `bash install.sh` de novo sem medo: o script **pula tudo que já está pronto** e só instala o que falta. Para trocar de versão (v1 para v2 ou o contrário), é só rodar e escolher a outra opção.

Para forçar a reinstalação completa de tudo:

```sh
FORCE=1 bash install.sh
```

## Se algo der errado

O script grava tudo que faz no arquivo `~/opencode-install.log` (dentro do Termux). Se aparecer `ERRO no passo: ...`, ele mesmo mostra as últimas linhas desse log na tela. Copie essa mensagem para pedir ajuda.

Problemas comuns:

- **Travou baixando o Debian**: confira a internet e rode de novo (ele continua de onde parou).
- **Senha esquecida**: rode o instalador de novo e cadastre uma senha nova.
- **Cópia no /sdcard não apareceu**: rode o instalador de novo, diga `s` na pergunta do armazenamento e toque em PERMITIR na caixa do Android.
- **Letras bagunçadas no banner**: o banner usa caracteres de bloco; se aparecer `�`, atualize o app Termux ou troque a fonte do terminal.

## O que tem dentro do script (`install.sh`)

Resumo para quem tem curiosidade do que roda no celular:

1. **Menu inicial** — pergunta se você quer a v1 ou a v2 e pede a senha (a senha nunca aparece no log).
2. **Diagnóstico** — anota no log o modelo do aparelho, espaço livre, versão da internet e o que já está instalado.
3. **Atualização do Termux** (`pkg update`) e instalação do **proot-distro** (programa que cria um "Debian dentro do Termux", porque o OpenCode precisa de um Linux completo).
4. **Instalação do Debian** dentro do proot-distro (etapa mais demorada, só acontece uma vez).
5. **Dependências do Debian** (`curl`, `ca-certificates`, `unzip`, `tar`).
6. **Instalação do OpenCode** (v1 ou v2, conforme sua escolha) dentro do Debian. O script confere se o programa realmente foi instalado e grava qual versão foi escolhida.
7. **Configuração final** — cria as pastas de configuração, salva sua senha com permissão restrita (só você lê) e cria o comando `opencode`, que na verdade é um atalho que abre o programa dentro do Debian repassando sua senha automaticamente.
8. **Cópia no dispositivo (só se ativada)** — copia `opencode.jsonc`, versão e senha para `/sdcard/opencode`.
9. **Verificação final** — roda `opencode --version` e avisa se a versão instalada bate com a escolhida.

Detalhes técnicos: checagens idempotentes por etapa (pula o que já existe, marcado como "já instalado"), lista de tarefas com spinner na etapa atual, log filtrado (barras de progresso do `curl` não poluem o log), arquivo opcional `banner.ans` de 106 colunas para capa personalizada, e variável `FORCE=1` para ignorar as checagens.
