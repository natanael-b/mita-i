Analise essa aplicação que estou desenvolvendo:

# Yvy

**Yvy** é uma forma prática de organizar e unificar diferentes aplicativos em uma suíte personalizada, por meio de uma estrutura simples baseada em pastas.

---

## Como funciona

O Yvy detecta automaticamente arquivos criados em pastas específicas do sistema  e gera aplicativos personalizados  que simplificam o fluxo de trabalho, um jeito fácil e prático de unificar aplicações.

### 1. Criação da estrutura

Crie uma pasta no seu usuário em `Recursos/Aplicativos/Lançadores`, por exemplo `Criação gráfica`, com a seguinte estrutura interna:

```
📂 Criação gráfica/
     ├── 📂 Aplicativos/
     └── 📂 Modelos/ (opcional)
```


- **Aplicativos**: arraste os aplicativos do menu de aplicativos que deseja agrupar nessa pasta.
- **Modelos**: adicione aqui os modelos que desejar usar. Consulte a [documentação sobre criação de modelos](Modelos.md) para aprender como criar categorias personalizadas.

### 2. Detecção automática

Após criar a estrutura, aguarde alguns segundos e o Yvy irá analisar a pasta e irá criar um novo lançador no menu do sistema, listando os aplicativos e modelos configurados.

### 3. Dicas adicionais

- O lançador herdará as categorias dos aplicativos incluídos.
- Ele pode ser definido como aplicativo padrão para abrir arquivos. Nesse caso, escolherá automaticamente o app interno apropriado.

---

## Remoção

Para remover o lançador, basta apagar a pasta que você criou em `Recursos/Aplicativos/Lançadores`.

---

## Personalização de ícone

1. Clique com o botão direito na pasta criada.
2. Vá em **Propriedades**.
3. Escolha um novo ícone.
