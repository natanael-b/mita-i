Ivy é um nome adequado?

# Yvy

**Yvy** (em _**guarani**_: terra, chão, base, fundamento) permite que você agrupe e integre aplicativos em conjuntos personalizados — como suítes integradas de produtividade — usando apenas pastas. É uma maneira simples e poderosa de organizar seu ambiente de trabalho no KDE Plasma.

---

## Índice

1. [O que é o Yvy?](#1-o-que-é-o-yvy)
2. [Como funciona](#2-como-funciona)
3. [Configuração por distribuição](#3-configuração-por-distribuição)
4. [Criando estruturas e modelos](#4-criando-estruturas-e-modelos)
5. [Detecção automática](#5-detecção-automática)
6. [Personalização e manutenção](#6-personalização-e-manutenção)
7. [Backup e restauração](#7-backup-e-restauração)

---

## 1. O que é o Yvy?

Yvy é um serviço para KDE Plasma que permite criar "aplicativos compostos" agrupando apps e modelos de arquivos em estruturas de pastas. Ele gera automaticamente lançadores no menu do sistema, facilitando fluxos de trabalho personalizados.

---

## 2. Como funciona

O Yvy monitora pastas específicas e, ao detectar novas estruturas de lançadores, cria automaticamente arquivos `.desktop` personalizados. Esses lançadores aparecem no menu do sistema como conjuntos integrados de aplicativos e modelos de documentos.

### Estrutura esperada:

```
📂 NomeDoGrupo/
 ├── 📂 Aplicativos/  ← Atalhos para apps agrupados
 └── 📂 Modelos/      ← Arquivos e pastas-modelo para novos documentos
```

* **Aplicativos**: arraste atalhos de apps desejados para cá.
* **Modelos**: organize modelos reutilizáveis por categorias (pastas).

---

## 3. Configuração por distribuição

### 🟢 Mita-i OS

* Monitora `Recursos/Aplicativos/Lançadores`.
* Criação, modificação ou remoção de subpastas resulta em atualização automática de lançadores.

### ⚪ Outras distribuições

#### Opção 1: Usar o local padrão do Yvy

* Pasta `~/Yvy Apps` é criada automaticamente.
* Qualquer estrutura válida criada aqui será detectada.

#### Opção 2: Verificar local configurado pela distro

```bash
xdg-user-dir GROUP_LAUNCHER_DIR
```

#### Opção 3: Definir local personalizado

```bash
xdg-user-dirs-update --set GROUP_LAUNCHER_DIR "/caminho/para/sua/pasta"
```

---

## 4. Criando estruturas e modelos

### Criando categorias de modelos

* Crie subpastas em `Modelos/` para categorias como `Relatórios`, `Projetos`, etc.
* O ícone da categoria será o ícone atribuído à pasta (Propriedades → Ícone no Dolphin).

### Arquivos em branco

Dentro de uma categoria:

* Nomeie arquivos como `_blank.ext` (ex: `_blank.odt`).

### Estruturas de diretório como modelo

Dentro de uma categoria:
* Coloque o arquivo modelo com o mesmo nome da pasta seguido da extensão
* Crie subpastas com arquivos e subdiretórios internos.
* Links simbólicos para pastas não são seguidos; apenas copiados.
* Ao criar oarquivo modelo será copiado para dentro da pasta

Exemplo:

```
📂 Modelos/
 ├── 📂 Exemplo/     ← Pasta contendo os arquivos do modelo
 └── 📄 Exemplo.ext  ← Arquivo de referencia que será usado para determinar o aplicativo
```

---

## 5. Detecção automática

* Após criar ou editar pastas, aguarde alguns segundos.
* Um lançador personalizado será criado no menu.

### Comportamento dos lançadores:

* Herdam categorias dos aplicativos incluídos.
* Podem abrir arquivos conforme o `MimeType` do sistema.
* Um mesmo app pode aparecer em múltiplos grupos.
* Conflitos com nomes idênticos são resolvidos priorizando o primeiro encontrado.

---

## 6. Personalização e manutenção

### Ícone do lançador

* Por padrão, usa o ícone do primeiro app.
* Para personalizar:
  - Clique direito na pasta do lançador.
  - Vá em **Propriedades** → **Ícone**.

### Remoção do lançador

* Basta apagar a pasta do lançador (ver [Configuração por distribuição](#3-configuração-por-distribuição) para o local).
* O lançador será removido automaticamente do menu.

---

## 7. Backup e restauração

* Copie as pastas para outro sistema.
* Lançadores ocultarão apps ausentes até que estes sejam instalados.
