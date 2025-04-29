# O diretório / do Mita-i OS

A ideia do Mita-i é ser um sistema que seja extremamente fácil reparar e gerenciar, então ele possui uma série de hooks e unificações, algumas estéticas outras nem tanto, a estrutura de diretórios / difere fortemente de distribuições linux tradicionais embora seja compatível:

#### `/applications`

Contém todos os itens que aparecem no menu de apps, podem ser de 4 tipos atualmente:
  - `flatpaks`
  - `native-apps`
  - `webapps`
  - `appimages`

Todos são adicionado na raiz sem uma distinção do que são, por exemplo, considere que você tenha o GIMP via Flatpak,  OnlyOffice via .deb, o Inkscape como AppImage, o Krita instalado pelo utilitário `native-app`, o Google Slides como WebApp, sua `/applications` seria:

```
/applications
  docs.google.com-presentation
  inkscape.appimage
  krita.app
  onlyoffice
  org.gimp.GIMP
```

>[!IMPORTANT]
>Esse diretório possui hooks:
> - Ao remover uma pasta o aplicativo é desinstalado e removido do menu

#### `/containers`

Contém containers para rodar aplicações por sandboxing, atualmente apenas Flatpaks fazem uso desse diretório

>[!IMPORTANT]
>Esse diretório possui hooks:
> - Ao remover uma pasta todos os aplicativos dependentes do container são desinstalados e removidos do menu

#### `/users`

Contém todo os diretórios pessoais dos usuários é similar a `/home`tradicional mas com um nome mais intuitivo, o diretório /root foi mesclado com essa pasta, /home ainda existe como um link simbólico para esse diretório

#### `/temp`

É o diretório /tmp com um nome mais legível

#### `/mita-i`

É onde a mágica acontece, todos os dados do sistema estão:

- `versions` Guarda versões do sistema, cada versão possui seu diretório independente, dentro do diretório da versão, existe os seguintes diretórios especiais:
  - `grub`, possui dados do grub, o diretório `/boot` irá apontar para esse diretório
  - `state`, possui dados de estado persistente do sistema, o diretório `/var` irá apontar para esse diretório
  - `config`, possui dados de configurações, o diretório `/etc` irá apontar para esse diretório
  - `run`, é um link simbólico para `/run`, permite usar serviços do SystemD

- `linux`, Provê acesso aos diretórios dinâmicos do kernel:

  - `processes`, possui dados de processos (link para /proc)
  - `devices`, permite acesso direto aos dispositivos  (link para /dev)
  - `kernel`, permite acesso direto às interfaces do Kernel Linux  (link para /sys)
  - `runtime`, dados do estado atual da execução do sistema  (link para /run)

- `shared`, armazena dados que são persistentes entre versões do sistema
  - `flatpaks`, armazena os objetos OSTree dos Flatpaks
  - `accounts`, armazena as contas dos usuários e ajustes no sudo
  - `utilities`, um `/bin` alternativo com o `busybox` estatico, útil para trocar de versão do sistema manualmente
- `system`, é um link simbólico para /usr

>[!TIP]
> O comando `basename $(realpath -m /mita-i/system)` retorna a versão ativa do sistema

-----------------------------------------------

Vários diretórios se tornaram links para /usr

- `/boot` -> `/usr/grub`
- `/etc` -> `/usr/config`
- `/var` -> `/usr/state`

E foram ocultos através do arquivo `.hidden`
