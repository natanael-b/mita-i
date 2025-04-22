#!/usr/bin/env bash

source . "distro.ini"

#-----------------------------------------------------------------------------------------------------------------------------------------
iso_repository="https://cdimage.ubuntu.com/kubuntu/releases/${base}/release/"
iso_file=$(wget -q -O - "${iso_repository}" | grep -o "kubuntu-${base}.*amd64.iso" | head -n1)
url="https://cdimage.ubuntu.com/kubuntu/releases/${base}/release/${iso_file}"
#-----------------------------------------------------------------------------------------------------------------------------------------

script=$(readlink -f "${0}")
step_count=$(grep "^function" ${script} | grep -Ev "print-help|EXIT|function-template" | wc -l)
current_step=0

#-----------------------------------------------------------------------------------------------------------------------------------------

# xorriso mtools dosfstools
function download-image {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Download image" 
    echo "---------------------------------------------------------"

    [ -f "base/filesystem.squashfs" ] && { return ; } || { echo ; }

    mkdir -p base
    cd base

    wget -c "${url}" -O "kubuntu.iso"
    osirrox -indev "kbuntu.iso" -extract /casper .
    rm -f filesystem.manifest filesystem.size filesystem.manifest-minimal-remove filesystem.manifest-remove filesystem.squashfs.gpg
    
    cd ..
}

function extract-image {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Extracting image" 
    echo "---------------------------------------------------------"

    [ -f "chroot/usr/bin/bash" ] && { return ; } || { echo ; }

    mkdir -p chroot
    ln -s chroot/ squashfs-root
    unsquashfs -f base/filesystem.squashfs
    rm squashfs-root

    (
      cd "chroot"
      rm -rf bin.usr-is-merged lib.usr-is-merged sbin.usr-is-merged 2> /dev/null
    )
}

function mount-virtual-fs {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Initialize virtual FS" 
    echo "---------------------------------------------------------"

    mount --bind /dev "chroot/dev"
    mount --bind /run "chroot/run"
    chroot "chroot" mount none -t proc /proc
    chroot "chroot" mount none -t devpts /dev/pts
}

function chroot-phase-1 {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Preparing base image" 
    echo "---------------------------------------------------------"

    [ -f "chroot/etc/TIGER_BUILD" ] && { return ; } || { echo ; }

    [ -d "rootfs/usr/share/plymouth/themes/kubuntu-logo" ] && {
        rm -rf "chroot/usr/share/plymouth/themes/kubuntu-logo"
        cp -rf "rootfs/usr/share/plymouth/themes/kubuntu-logo" "chroot/usr/share/plymouth/themes/"
    }

    # Fix permissions to /var/lib/apt/lists
    chroot "chroot" mkdir -p /var/lib/apt/lists
    chroot "chroot" sudo chown -R _apt:root /var/lib/apt/lists
    # Update casper and mark as manually installed if needed
    chroot "chroot" apt install casper  -y
    chroot "chroot" apt remove libreoffice* elisa  thunderbird konversation apport*   \
                               kmines kpat ksudoku kmahjongg info  ksystemlog         \
                               kwalletmanager khelpcenter im-config partitionmanager  \
                               kde-config-tablet unattended-upgrades usb-creator-kde  \
                              ubuntu-advantage-tools -y
    
    # Fallback for 22.04 and bellow
    chroot "chroot" apt-get -q remove vlc -y 2>&1 > /dev/null

    # Fallback for 24.04 and above
    chroot "chroot" apt-get -q remove ktorrent            -y 2>&1 > /dev/null
    chroot "chroot" apt-get -q remove pavucontrol-qt      -y 2>&1 > /dev/null
    chroot "chroot" apt-get -q remove krdc                -y 2>&1 > /dev/null
    chroot "chroot" apt-get -q remove pavucontrol-qt-l10n -y 2>&1 > /dev/null

    # Plasma Welcome
    chroot "chroot" apt-get -q remove plasma-welcome -y 2>&1 > /dev/null

    # Ubiquity
    chroot "chroot" apt-get -q purge ubiquity* -y 2>&1 > /dev/null

    # Calamares
    chroot "chroot" apt-get -q purge calamares* -y 2>&1 > /dev/null

    # Neochat
    chroot "chroot" apt-get -q purge neochat* -y 2>&1 > /dev/null

    chroot "chroot" apt autoremove -y

    # Add PPAs
    chroot "chroot" add-apt-repository ppa:mozillateam/ppa -y
    chroot "chroot" add-apt-repository ppa:yannubuntu/boot-repair -y

    # Avoid use of Firefox Snap
    (
        echo 'Package: *'
        echo 'Pin: release o=LP-PPA-mozillateam'
        echo 'Pin-Priority: 1001'
    ) > "chroot/etc/apt/preferences.d/mozilla-firefox"

    # Upgrade the system
    chroot "chroot" apt update
    chroot "chroot" apt upgrade --allow-downgrades -y 

    # Keyboard layout
    sed -i "s/us/${keyboard}/g" "chroot/etc/default/keyboard"

    # Set locale to pt_BR
    chroot "chroot" sh -c "echo 'grub-pc grub-pc/install_devices_empty   boolean true'                  | debconf-set-selections"
    chroot "chroot" sh -c "echo 'locales locales/locales_to_be_generated multiselect pt_BR.UTF-8 UTF-8' | debconf-set-selections"
    chroot "chroot" sh -c "echo 'locales locales/default_environment_locale select pt_BR.UTF-8'         | debconf-set-selections"
    chroot "chroot" sh -c "echo 'debconf debconf/frontend select Noninteractive'                        | debconf-set-selections"

    # Inject casper on initrd
    chroot "chroot" apt install ${packagesToInstall[@]} --install-recommends --allow-downgrades -y

    local kernel=$(chroot chroot/ dpkg -l | grep linux-image-.*-generic | cut -d' ' -f 3)
    chroot "chroot" apt install casper ${kernel} --reinstall --allow-downgrades -y
}

# Remove snaps and enable Flatpaks
function chroot-phase-2 {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Removing snaps" 
    echo "---------------------------------------------------------"
    
    [ -f "chroot/etc/TIGER_BUILD" ] && { return ; } || { echo ; }

    rm -rf "chroot/var/lib/snapd"
    rm -rf "chroot/etc/systemd/system"/snap*
    rm -rf "chroot/snap"

    chroot "chroot" apt autoremove snapd -y
}

function chroot-phase-3 {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Installing native apps" 
    echo "---------------------------------------------------------"

    [ -f "chroot/etc/TIGER_BUILD" ] && { return ; } || { echo ; }

    # Ubuntu native apps
    mapfile -t packagesToInstall < <(sed 's|#.*$||g;s|\r||' data/ubuntu-packages.lst | awk NF)

    chroot "chroot" apt install ${packagesToInstall[@]} --allow-downgrades -y
}

function chroot-phase-4 {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Download OS Installer" 
    echo "---------------------------------------------------------"

    [ -f "chroot/etc/TIGER_BUILD" ] && { return ; } || { echo ; }

    chroot "chroot" wget -q https://raw.githubusercontent.com/natanael-b/linstaller/main/linstaller-backend -O /usr/bin/linstaller-backend
    chroot "chroot" chmod +x /usr/bin/linstaller-backend

    chroot "chroot" wget -q https://raw.githubusercontent.com/natanael-b/linstaller/main/linstaller-fulldisk-setup -O /usr/bin/linstaller-fulldisk-setup
    chroot "chroot" chmod +x /usr/bin/linstaller-fulldisk-setup

    local packagesToInstall=(
        gdisk
        squashfs-tools
        grub-common
        grub-pc-bin
        grub-efi
        grub-efi-amd64-signed
        dosfstools
        libarchive-tools
    )
    
    chroot "chroot" apt install ${packagesToInstall[@]} -y
}

function chroot-phase-5 {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Download standalone DEBs" 
    echo "---------------------------------------------------------"

    [ -f "chroot/etc/TIGER_BUILD" ] && { return ; } || { echo ; }

    mapfile -t packages < <(sed 's|#.*$||g;s|\r||' data/debian-packages-urls.lst | awk NF)

    mkdir -p "debian-packages"
    cd "debian-packages"

    for url in ${packages[@]}; do
      local filename=$(basename "${url}")
      wget -q --show-progress "${url}" -O $(basename "${url}")
      chmod a+rw "${filename}"
    done

    cd ..
}

function chroot-phase-6 {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Installing standalone DEBs" 
    echo "---------------------------------------------------------"
    [ -f "chroot/etc/TIGER_BUILD" ] && { return ; } || { echo ; }

    [ -d "debian-packages" ] && {
        echo
        mkdir -p "chroot/debian-packages"
        mount --bind "debian-packages" "chroot/debian-packages"

        chroot "chroot" sh -c 'apt install /debian-packages/* -y'
    }    
}

function chroot-phase-7 {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Copy system patches" 
    echo "---------------------------------------------------------"

    [ -f "chroot/etc/TIGER_BUILD" ] && { return ; } || { echo ; }
    

    [ -d "rootfs" ] && {
        chmod +x "rootfs/usr/local/bin"/*
        cp -rf rootfs/* "chroot"
    }
}

function chroot-phase-8 {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Setup WebApp Player" 
    echo "---------------------------------------------------------"

    [ -f "chroot/etc/TIGER_BUILD" ] && { return ; } || { echo ; }

    (
        mkdir -p "chroot/usr/local/share/webapp-player/"
        cd "chroot/usr/local/share/webapp-player/"
        wget -q "https://github.com/electron/electron/releases/download/v33.0.2/electron-v33.0.2-linux-x64.zip" -O electron.zip
        unzip -o electron.zip
        mkdir -p "webapp-player"
        echo "
          const { app, BrowserWindow } = require('electron/main')
          const path = require('node:path')

          app.setName(process.argv[3])

          function createWindow () {
            const win = new BrowserWindow({
            width: 800,
            height: 600,
            darkTheme: true,
            menuBarVisible: false,
            title: process.argv[4],
            icon: process.argv[5],
            webPreferences: {
              devTools: false,
              spellcheck: false,
              enableWebSQL: false,
            }
          });

          win.setMenu(null);
          win.webContents.once('did-finish-load',   () => { win.setMenu(null);});
          win.webContents.once('did-start-loading', () => { win.setMenu(null);});
          win.webContents.once('did-stop-loading',  () => { win.setMenu(null);});
          win.webContents.once('dom-ready',         () => { win.setMenu(null);});
          win.webContents.once('will-redirect',     () => { win.setMenu(null);});

          win.loadURL(process.argv[3]);
        }

        app.whenReady().then(() => {
          createWindow()

          app.on('activate', () => {
            if (BrowserWindow.getAllWindows().length === 0) {
              createWindow()
            }
          })
        })

        app.on('window-all-closed', () => {
          if (process.platform !== 'darwin') {
            app.quit()
          }
        })" | sed 's|^          ||g' > "webapp-player/index.js"
        rm "electron.zip" || true 2>&1 > /dev/null
    )

    echo -e '#!/usr/bin/env bash\n/usr/local/share/webapp-player/electron --no-sandbox /usr/local/share/webapp-player/ "${1}" "${2}" "${3}"' > "chroot/usr/local/bin/webapp-player"
    chmod +x "chroot/usr/local/bin/webapp-player"
}

function chroot-phase-9 {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Cleaning up" 
    echo "---------------------------------------------------------"

    rm -rf "chroot/usr/share/icons"/Oxygen*      2> /dev/null
    rm -rf "chroot/usr/share/icons"/ubuntu-mono* 2> /dev/null
    rm -rf "chroot/usr/share/icons"/Humanity*    2> /dev/null
    rm -rf "chroot/usr/share/wallpapers"         2> /dev/null
    
    rm -rf "chroot/usr/share/plasma/look-and-feel/org.kubuntu.desktop" 2> /dev/null

    mkdir -p "chroot/usr/share/wallpapers"
}

function chroot-phase-10 {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Remove old kernels" 
    echo "---------------------------------------------------------"

    echo
    [ -f "chroot/etc/TIGER_BUILD" ] && { return ; } || { echo ; }

    local in_use=$(basename $(chroot "chroot" readlink -f /boot/vmlinuz) | cut -c 9-)
    local old_kernels=$(
      chroot "chroot" dpkg --list |
        grep -v "${in_use}" |
        grep -Ei 'linux-image|linux-headers|linux-modules' |
        awk '{ print $2 }'
    )

    for package in ${old_kernels}; do
        yes | chroot "chroot" apt-get -qq purge "${package}"
    done

    chroot "chroot" ls /lib/modules/ | grep -v ${in_use} | sed 's|^|chroot "chroot" rm -rf /lib/modules/|g' | sh
}

function chroot-phase-11 {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Running post build" 
    echo "---------------------------------------------------------"

    [ -f "chroot/etc/TIGER_BUILD" ] && { return ; } || { echo ; }

    [ -f "chroot/usr/bin/extra-steps.sh" ] && {
        chmod +x "chroot/usr/bin/extra-steps.sh"
        chroot "chroot" bash "/usr/bin/extra-steps.sh"
        rm "chroot/usr/bin/extra-steps.sh" 2> /dev/null

        chmod +x "chroot/usr/bin/post-install"
    }

    touch "chroot/etc/TIGER_BUILD"
}

function umount-virtual-fs {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Finishing virtual FS" 
    echo "---------------------------------------------------------"
    echo

    echo "RESUME=none"   > "chroot/etc/initramfs-tools/conf.d/resume"
    echo "FRAMEBUFFER=y" > "chroot/etc/initramfs-tools/conf.d/splash"

    umount -l "chroot/dev/pts"
    umount -l "chroot/dev"
    umount -l "chroot/proc"
    umount -l "chroot/run"
    umount -l "chroot/debian-packages"

    # We need to ensure that is unmounted
    umount -l "chroot/dev/pts"
    umount -l "chroot/dev"
    umount -l "chroot/proc"
    umount -l "chroot/run"
    umount -l "chroot/debian-packages"

    # Cleanup history and cache
    rm -rf chroot/home/*
    rm -rf chroot/tmp/*
    rm -rf chroot/debian-packages
}

function build-squashfs {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Rebuilding image" 
    echo "---------------------------------------------------------"
    echo

    mkdir -pv image/{boot/grub,casper,isolinux,preseed}
    mksquashfs chroot image/casper/filesystem.squashfs -comp xz -noappend
}

function build-grub {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Build GRUB image" 
    echo "---------------------------------------------------------"

    [ -f "image/isolinux/grub.cfg" ] && { return ; } || { echo ; }

    cp --dereference chroot/boot/vmlinuz    image/casper/vmlinuz
    cp --dereference chroot/boot/initrd.img image/casper/initrd

    (
        echo
        echo "menuentry \"${grub_name}\" {"
        echo "   linux /casper/vmlinuz file=/cdrom/preseed/${name}.seed boot=casper ${splash} username=${user} hostname=${host} locale=pt_BR ---"
        echo "   initrd /casper/initrd"
        echo "}"

        echo "menuentry \"${grub_name} (Modo Recovery)\" {"
        echo "   linux /casper/vmlinuz file=/cdrom/preseed/${name}.seed boot=casper ${splash} username=${user} hostname=${host} locale=pt_BR recovery ---"
        echo "   initrd /casper/initrd"
        echo "}"

        echo "menuentry \"${grub_name} (Modo Recovery - failseafe)\" {"
        echo "   linux /casper/vmlinuz file=/cdrom/preseed/${name}.seed boot=casper ${splash} username=${user} hostname=${host} locale=pt_BR nomodeset recovery ---"
        echo "   initrd /casper/initrd"
        echo "}"

        echo "menuentry \"${grub_name} (Modo de desempenho - Inseguro)\" {"
        echo "   linux /casper/vmlinuz file=/cdrom/preseed/${name}.seed boot=casper ${splash} username=${user} hostname=${host} locale=pt_BR mitigations=off ---"
        echo "   initrd /casper/initrd"
        echo "}"

        echo "menuentry \"${grub_name} (Iniciar na RAM)\" {"
        echo "   linux /casper/vmlinuz file=/cdrom/preseed/${name}.seed boot=casper ${splash} username=${user} hostname=${host} locale=pt_BR toram ---"
        echo "   initrd /casper/initrd"
        echo "}"

        echo "menuentry \"${grub_name} - NVIDIA Legacy\" {"
        echo -n "   linux /casper/vmlinuz file=/cdrom/preseed/${name}.seed boot=casper ${splash} username=${user} hostname=${host} locale=pt_BR"
        echo    "   modprobe.blacklist=nvidia,nvidia_uvm,nvidia_drm,nvidia_modeset ---"
        echo "   initrd /casper/initrd"
        echo "}"

        echo "menuentry \"${grub_name} - Intel Atom(R) (Modo Compatibilidade)\" {"
        echo -n "   linux /casper/vmlinuz file=/cdrom/preseed/${name}.seed boot=casper ${splash} username=${user} hostname=${host} locale=pt_BR"
        echo    "   rtl8723bs.11n_disable=1 modprobe.blacklist=snd_hdmi_lpe_audio mitigations=off snd_sof.sof_debug=1 ipv6.disable=1 iatom=1 ---"
        echo "   initrd /casper/initrd"
        echo "}"
        
        echo "menuentry \"Reboot\" {reboot}"
        echo "menuentry \"Shutdown\" {halt}"
        echo
    ) > image/boot/grub/loopback.cfg


    (
        echo
        echo "search --set=root --file /${name}"
        echo "insmod all_video"
        echo "set default=\"0\""
        echo "set timeout=15"
        
        echo "if loadfont /boot/grub/unicode.pf2 ; then"
        echo "    insmod gfxmenu"
        echo "	insmod jpeg"
        echo "	insmod png"
        echo "	set gfxmode=auto"
        echo "	insmod efi_gop"
        echo "	insmod efi_uga"
        echo "	insmod gfxterm"
        echo "	terminal_output gfxterm"
        echo "fi"

        cat "image/boot/grub/loopback.cfg"
        echo
    ) > image/isolinux/grub.cfg

    (
        echo "#define DISKNAME   ${name}"
        echo "#define TYPE       binary"
        echo "#define TYPEbinary 1"
        echo "#define ARCH       amd64"
        echo "#define ARCHamd64  1"
        echo "#define DISKNUM    1"
        echo "#define DISKNUM1   1"
        echo "#define TOTALNUM   0"
        echo "#define TOTALNUM0  1"
    ) > "image/README.diskdefines"
    
    (
        cd image
        touch "${name}"

        grub-mkstandalone                                   \
          --format=x86_64-efi                               \
          --output=isolinux/bootx64.efi                     \
          --locales=""                                      \
          --fonts="" "boot/grub/grub.cfg=isolinux/grub.cfg"

        (
            cd isolinux 
            dd if=/dev/zero of=efiboot.img bs=1M count=10
            mkfs.vfat efiboot.img
            mmd -i efiboot.img efi efi/boot
            mcopy -i efiboot.img ./bootx64.efi ::efi/boot/
        )
        
        grub-mkstandalone --format=i386-pc --output=isolinux/core.img                      \
          --install-modules="linux16 linux normal iso9660 biosdisk memdisk search tar ls"  \
          --modules="linux16 linux normal iso9660 biosdisk search" --locales="" --fonts="" \
          "boot/grub/grub.cfg=isolinux/grub.cfg"
          
        cat /usr/lib/grub/i386-pc/cdboot.img isolinux/core.img > isolinux/bios.img
    )
}

function build-iso {
    cd image
    
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Building ISO file" 
    echo "---------------------------------------------------------"
    echo

    bash -c '(find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt)'
    mkdir -pv ../iso

    xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames        \
      -volid "${name}" -eltorito-boot boot/grub/bios.img            \
      -no-emul-boot -boot-load-size 4 -boot-info-table              \
      --eltorito-catalog boot/grub/boot.cat --grub2-boot-info       \
      --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img             \
      -eltorito-alt-boot -e /EFI/BOOT/BOOTX64.efi                   \
      -no-emul-boot -append_partition 2 0xef isolinux/efiboot.img   \
      -output "../iso/${name}-amd64.iso" -graft-points "."          \
        /boot/grub/bios.img=isolinux/bios.img                       \
        /EFI/BOOT/BOOTX64.efi=isolinux/efiboot.img
         
    md5sum ../iso/${name}-amd64.iso > ../iso/${name}-amd64.md5
    
    ISO=$(readlink -f ../iso/${name}-amd64.iso)

    cd ..
    
    [ -f "${ISO}" ] && {
        echo
        echo "---------------------------------------------------------"
        echo "  ISO: "
        echo "    "$( du -sh "${ISO}")
        echo "---------------------------------------------------------"
        echo

        exit 0
    }

    echo "Failed to generate ISO"
    exit 1
}

function print-help {
echo "

  Live System Builder 1.0
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

System Bootable Image Builder options:

  --init        ; Create the directory structure and exit
  --cleanup     ; Remove the chroot and image directories
  --remove-isos ; Remove the ISOs
  --remove-all  ; Remove all directories except rootfs
  --force       ; Bypass rebuild protection
  --chroot      ; Enter chroot mode
  --update      ; Update packages before generating the ISO

Directories and their meanings

  data            ; Package lists
  debian-packages ; The .deb packages here will be installed on the ISO
  image           ; Root of the ISO file
  rootfs          ; The files here will be copied to the squashfs
  iso             ; Where the ISOs will be saved

Special scripts:
  rootfs/usr/bin/post-install ; Run after installing the system
  rootfs/usr/bin/build-script ; Run before compacting squashfs
"
}

function EXIT {
    # Let's make everything as possible to keep base 
    # system on a consistent state
    {
        umount-virtual-fs
        umount-virtual-fs
        umount-virtual-fs
        umount-virtual-fs
        umount-virtual-fs
        umount-virtual-fs
        umount-virtual-fs
    } &> /dev/null
     2>&1 > /dev/null
}

trap EXIT EXIT

dependencies=(debootstrap mtools squashfs-tools xorriso casper lib32gcc-s1 grub-common grub-pc-bin grub-efi)

missing=""
for dep in ${dependencies[@]}; do
  dpkg -s ${dep} 2>/dev/null >/dev/null || {
    missing=" ${missing} ${dep}"
  }
done

[ ! "${missing}" = "" ] && {
  echo y | apt install ${dependencies[@]} -y
}

[ ! -n "${SUDO_USER}" ] && {
    echo
    echo "Forma errada de executar o script, use:"
    echo
    echo "  sudo su; ${0} ${@}"
    echo
    exit 1
}

USE_CHROOT=false
DO_UPDATE=false
COLOR=""
MODE=""

for arg in ${@}; do
    [ "${arg}" = "--init" ] && {
        mkdir -p debian-packages rootfs image/{boot/grub,casper,isolinux,preseed} ;
        exit 0 ;
    }

    [ "${arg}" = "--cleanup" ] && {
        rm -rf "chroot" "image" "debian-packages" 2> /dev/null ;
        sync
        shift ;
    }

    [ "${arg}" = "--remove-isos" ] && {
        rm -rf "iso" 2> /dev/null ;
        sync
        shift ;
    }

    [ "${arg}" = "--remove-all" ] && {
        rm -rf "chroot" "base" "image" "iso" 2> /dev/null ;
        sync
        shift ;
    }

    [ "${arg}" = "--force" ] && {
        rm -rf "chroot/etc/TIGER_BUILD"  2> /dev/null ;
        rm -rf "image/isolinux/grub.cfg" 2> /dev/null ;
        sync
        shift ;
    }


    [ "${arg}" = "--help" ] && {
        print-help | less
        exit 0 ;
    }

    [ "${arg}" = "--chroot" ] && {
        USE_CHROOT=true
        shift ;
    }

    [ "${arg}" = "--update" ] && {
        DO_UPDATE=true
        shift ;
    }
done

mkdir -p debian-packages rootfs image/{boot/grub,casper,isolinux,preseed} ;

download-image
extract-image
mount-virtual-fs
chroot-phase-1
chroot-phase-2
chroot-phase-3
chroot-phase-4
chroot-phase-5
chroot-phase-6
chroot-phase-7
chroot-phase-8

[ "${USE_CHROOT}" = "true" ] && {
    chroot "chroot" bash;
    rm "image/isolinux/grub.cfg"
    sync
}

mkdir -p "chroot/usr/share/tiger-home/.config"
echo -n "" > "chroot/usr/share/tiger-home/.config/tiger-welcome"

[ ! "${COLOR}" = "" ] && {
    echo "Color:${COLOR}" >> "chroot/usr/share/tiger-home/.config/tiger-welcome"
}

[ ! "${MODE}" = "" ] && {
    echo "Mode:${MODE}" >> "chroot/usr/share/tiger-home/.config/tiger-welcome"
}

chroot-phase-9
chroot-phase-10
chroot-phase-11
umount-virtual-fs
build-squashfs
build-grub
build-iso
