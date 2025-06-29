# TempFile Host Utilities

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Shell](https://img.shields.io/badge/Shell-Bash-blue)

Scripts para upload rápido de arquivos para o serviço [0x0.st](https://0x0.st) diretamente da linha de comando (CLI) ou através de uma interface gráfica simples (GUI).

---

### Demonstração

**Versão CLI (`tempfile-host`):**
```sh
$ tempfile-host meu_script.py
▶ Enviando meu_script.py...
📤 Realizando upload para https://0x0.st...

✔ Upload concluído!
  Link: https://0x0.st/AbCd.py

ℹ️  Nota: Arquivos no 0x0.st podem ser removidos a qualquer momento...
📋 Link copiado para a área de transferência (Wayland).
📜 Link salvo em: /home/user/.config/tempfile-host/history.log
```

**Versão GUI (`tempfile-host-gui`):**

A versão gráfica oferece um fluxo intuitivo:
1.  Um seletor de arquivos é aberto para você escolher o que enviar.
2.  Uma barra de progresso é exibida durante o upload.
3.  Uma janela de sucesso mostra o link final e confirma que ele foi copiado.

---

## 📄 Sobre o Projeto

Este repositório contém duas ferramentas projetadas para agilizar o compartilhamento temporário de arquivos:

1.  **`tempfile-host.sh`**: Uma ferramenta de linha de comando poderosa, ideal para automação e para usuários que vivem no terminal.
2.  **`tempfile-host-gui.sh`**: Uma interface gráfica simples, baseada em `Zenity`, que oferece uma experiência de "apontar e clicar" para o upload de arquivos.

## ✨ Recursos Principais

*   **Interface Dupla (CLI & GUI)**: Use o terminal ou uma janela gráfica.
*   **Suporte a `stdin`**: Envie a saída de outros comandos diretamente.
*   **Integração com Área de Transferência**: O link do upload é copiado automaticamente.
*   **Histórico de Uploads**: Um registro de todos os seus uploads é mantido.
*   **Notificações no Desktop**: Receba uma notificação nativa ao final do upload.
*   **Seguro e Robusto**: Valida o tamanho do arquivo e trata falhas de forma elegante.

> 📖 Para uma explicação detalhada de cada um desses recursos, visite a página **[Recursos Detalhados](https://github.com/marcelositr/tempfile-host/wiki/Recursos-Detalhados)** na nossa Wiki.

## 🚀 Instalação e Configuração

### 1. Pré-requisitos
Certifique-se de que as dependências necessárias estão instaladas.
-   **Essencial**: `curl`
-   **Para a GUI**: `zenity`
-   **Opcional (recomendado)**: `xclip` (X11), `wl-clipboard` (Wayland), `libnotify-bin` (notificações).

### 2. Instalação
Clone o repositório e torne os scripts executáveis:
```bash
git clone https://github.com/marcelositr/tempfile-host.git
cd tempfile-host
chmod +x tempfile-host.sh tempfile-host-gui.sh
```

### 3. (Recomendado) Acesso Global
Mova os scripts para seu `PATH` para poder chamá-los de qualquer lugar:
```bash
sudo mv tempfile-host.sh /usr/local/bin/tempfile-host
sudo mv tempfile-host-gui.sh /usr/local/bin/tempfile-host-gui
```

> 📖 Para um guia passo a passo mais detalhado, incluindo comandos para outras distribuições Linux e dicas de configuração, consulte nosso **[Guia de Instalação na Wiki](https://github.com/marcelositr/tempfile-host/wiki/Instalação)**.

## 💻 Como Usar

### Linha de Comando (`tempfile-host`)

-   **Enviar um arquivo:**
    ```bash
    tempfile-host /caminho/para/seu/arquivo.txt
    ```

-   **Enviar texto via pipe:**
    ```bash
    echo "Este é um teste de upload." | tempfile-host
    ```

### Interface Gráfica (`tempfile-host-gui`)

-   Execute o comando no seu terminal ou crie um atalho no seu menu de aplicativos:
    ```bash
    tempfile-host-gui
    ```
    Uma janela se abrirá para que você possa selecionar o arquivo.

> 📖 Esses são os usos básicos. Para exemplos mais avançados, como o uso com outros comandos e dicas de produtividade, veja o **[Guia de Uso completo na Wiki](https://github.com/marcelositr/tempfile-host/wiki/Guia-de-Uso)**.

## 📚 Documentação Completa (Wiki)

Este `README` oferece um início rápido. Para a documentação completa, detalhes técnicos e guias de solução de problemas, **[visite a Wiki do projeto](https://github.com/marcelositr/tempfile-host/wiki)**.

Lá você encontrará:
-   Guias detalhados de instalação e uso.
-   Explicações sobre o arquivo de histórico e configuração.
-   Um guia completo de solução de problemas (Troubleshooting).
-   Informações sobre o serviço `0x0.st` e muito mais.

## 📜 Licença

Distribuído sob a licença MIT.

---
Feito com ❤️ por [Marcelo Sitr](https://github.com/marcelositr).
```
