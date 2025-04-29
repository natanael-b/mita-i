#!/usr/bin/env bash


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
    osirrox -indev "kubuntu.iso" -extract /casper .
    rm -f filesystem.manifest filesystem.size filesystem.manifest-minimal-remove filesystem.manifest-remove filesystem.squashfs.gpg
    
    cd ..
}

function extract-image {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Extracting image" 
    echo "---------------------------------------------------------"
    echo

    mkdir -p chroot
    ln -s chroot/ squashfs-root
    unsquashfs -f base/filesystem.squashfs
    rm squashfs-root

    (
      cd "chroot"
      rm -rf bin.usr-is-merged lib.usr-is-merged sbin.usr-is-merged
    )
}

function mount-virtual-fs {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Initialize virtual FS" 
    echo "---------------------------------------------------------"

    mkdir -p chroot/{dev/pts,run,proc,sys}

    echo "  - Mounting /dev"
    mount --bind /dev "chroot/dev"

    echo "  - Mounting /run"
    mount --bind /run "chroot/run"

    echo "  - Mounting /proc"
    chroot "chroot" mount none -t proc /proc

    echo "  - Mounting /dev/pts"
    chroot "chroot" mount none -t devpts /dev/pts
}

function chroot-phase-1 {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Preparing base image" 
    echo "---------------------------------------------------------"
    echo
    # Fix permissions to /var/lib/apt/lists
    chroot "chroot" mkdir -p /var/lib/apt/lists
    chroot "chroot" chown -R _apt:root /var/lib/apt/lists

    # Keyboard layout
    sed -i "s/us/${keyboard}/g" "chroot/etc/default/keyboard"

    # Set locale to pt_BR
    chroot "chroot" sh -c "echo 'grub-pc grub-pc/install_devices_empty   boolean true'                  | debconf-set-selections"
    chroot "chroot" sh -c "echo 'locales locales/locales_to_be_generated multiselect pt_BR.UTF-8 UTF-8' | debconf-set-selections"
    chroot "chroot" sh -c "echo 'locales locales/default_environment_locale select pt_BR.UTF-8'         | debconf-set-selections"
    chroot "chroot" sh -c "echo 'debconf debconf/frontend select Noninteractive'                        | debconf-set-selections"

    echo '#!/bin/bash
if [ ! -L /etc ]; then
  mv /etc /usr/config
  ln -s /usr/config /etc

  mkdir -p "/'${system_dir}'/shared/accounts/"

  for file in passwd shadow group gshadow login.defs sudoers sudoers.d; do
    if [ ! -L "/etc/${file}" ]; then
      mv "/etc/${file}" "/mita-i/shared/accounts"
    fi
    ln -fs "/'${system_dir}'/shared/accounts/${file}" "/etc/${file}"
  done
fi
' > "chroot/usr/sbin/mita-i-etc-merge"
    chmod +x "chroot/usr/sbin/mita-i-etc-merge"

    echo '[Unit]
Description=Merge /etc with /usr
DefaultDependencies=no
Before=sysinit.target
ConditionPathIsSymbolicLink=!/etc

[Service]
Type=oneshot
ExecStart=/usr/sbin/mita-i-etc-merge
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
' > "chroot/etc/systemd/system/mita-i-etc-merge.service"
    mkdir -p /etc/systemd/system/sysinit.target.wants
    chroot "chroot" ln -s /etc/systemd/system/mita-i-etc-merge.service /etc/systemd/system/sysinit.target.wants/mita-i-etc-merge.service

    # Regenerate vmlinuz
    local kernel=$(chroot chroot/ dpkg -l | grep linux-image-.*-generic | cut -d' ' -f 3)
    chroot "chroot" apt update
    chroot "chroot" apt install casper ${kernel} --reinstall --allow-downgrades -y
}

function chroot-phase-2 {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Remove pacotes indesejados" 
    echo "---------------------------------------------------------"
    echo

    chroot "chroot" apt autoremove --purge $(sed "s|#.*||g" data/remove-packages.lst | xargs) -y

    # Remove snaps only to reduce ISO size, snaps are freinds :)
    rm -rf chroot/var/lib/snapd chroot/snap chroot/var/snap chroot/usr/lib/snapd
    find chroot/etc/systemd -name "*snap*" -delete
    find chroot/etc/systemd -type d -name "*snap*" -exec rm -r {} +    
}

function chroot-phase-3 {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Instala pacotes extras" 
    echo "---------------------------------------------------------"
    echo

    chroot "chroot" apt install $(sed "s|#.*||g" data/install-packages.lst | xargs) -y
}

function chroot-phase-4  {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Baixar pacotes Debian" 
    echo "---------------------------------------------------------"
    echo
}

function chroot-phase-5 {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Aplica a estrutura do Mita'i OS" 
    echo "---------------------------------------------------------"
    echo

    (
      cd "chroot"

      echo "  - Create Mita'i base directory"
      mkdir -p "${system_dir}/versions/"
      mkdir -p "${system_dir}/linux/"
      mkdir -p "${system_dir}/shared/accounts"
      mkdir -p "${system_dir}/shared/flatpaks"
      mkdir -p applications
      mkdir -p containers

      for file in passwd shadow group gshadow login.defs; do
        cp "etc/${file}" "${system_dir}/shared/accounts"
      done

      echo "  - Merge /boot with /usr"
      mv boot usr/grub
      ln -s usr/grub boot

      echo "  - Merge /var with /usr"
      mv var usr/state
      ln -s usr/state var

      echo "  - Merge /mnt with /media"
      mv mnt media/0-devices
      ln -s media/0-devices mnt

      echo "  - Merge /opt with applications/thirdparty"
      mv opt applications/thirdparty
      ln -s applications/thirdparty opt

      echo "  - Merge Flatpak with /applications"
      mkdir -p "/${system_dir}/shared/flatpaks"
      ln -s "/${system_dir}/shared/flatpaks"  var/lib/flatpak
      ln -s /applications "${system_dir}/shared/flatpaks/app"
      ln -s /containers "${system_dir}/shared/flatpaks/runtime"

      echo "  - Move /usr to Mita'i OS directory"
      mv usr "${system_dir}/versions/${system_version}"
      ln -s "${system_dir}/versions/${system_version}" usr
      ln -s /usr "${system_dir}/system"
      # /etc/resolv.conf é um link relativo
      ln -fs /run "${system_dir}/versions/${system_version}/run"

      echo "  - Rename /home as /users"
      mv home/ users
      ln -s users home

      echo "  - Merge /root with /users"
      mkdir -p home/root
      rm -rf root
      chown root:root home/root
      chmod 700 home/root
      ln -s home/root root
      chown root:root root
      chmod 700 root
    
      echo "  - Rename /tmp as /temp"
      mv tmp temp
      ln -s temp tmp


      echo "  - Populate Mita'i OS linux directory"
      ln -fs /dev "${system_dir}/linux/devices"
      ln -fs /sys "${system_dir}/linux/kernel"
      ln -fs /run "${system_dir}/linux/runtime"
      ln -fs /proc "${system_dir}/linux/processes"


      # Generate the .hidden file
      (
        echo "bin"
        echo "boot"
        echo "dev"
        echo "etc"
        echo "home"
        echo "lib"
        echo "lib64"
        echo "mnt"
        echo "opt"
        echo "proc"
        echo "root"
        echo "rofs"
        echo "run"
        echo "sbin"
        echo "srv"
        echo "swapfile"
        echo "sys"
        echo "tmp"
        echo "usr"
        echo "var"
      ) > .hidden
    )
}

function cleanup {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Limpeza final do Mita'i OS" 
    echo "---------------------------------------------------------"
    echo

    echo "  - Hide useless itens from menu"
    mkdir -p chroot/usr/local/share/applications
    for file in $(sed "s|#.*||g" data/hide-from-menu.lst | xargs); do
      if [ -f "chroot/usr/local/share/applications/${file}" ]; then
        rm "chroot/usr/local/share/applications/${file}"
      fi
      cp "chroot/usr/share/applications/${file}" "chroot/usr/local/share/applications"
      sed -i 's|\[Desktop Entry]|[Desktop Entry]\nNoDisplay=true|g' "chroot/usr/local/share/applications/${file}"
    done
    
    echo "  - Cleaning up APT"
    chroot "chroot" apt clean

    echo "  - Cleaning up logs"
    chroot "chroot" find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
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

    mounts=(
        "chroot/dev/pts"
        "chroot/dev"
        "chroot/proc"
        "chroot/run"
        "chroot/debian-packages"
    )

    for mount_point in "${mounts[@]}"; do
        while mountpoint -q "${mount_point}"; do
            echo "  - Unmounting ${mount_point}"
            umount -l "${mount_point}" 2>/dev/null
            sleep 0.5
        done
    done

    # Cleanup history and cache
    rm -rf chroot/tmp/*
    rm -rf chroot/debian-packages    || true 2>&1 > /dev/null
    rm -rf chroot/lib.usr-is-merged  || true 2>&1 > /dev/null
    rm -rf chroot/sbin.usr-is-merged || true 2>&1 > /dev/null
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

function EXIT {
    # Let's make everything as possible to keep base 
    # system on a consistent state
    {
        umount-virtual-fs
    } &> /dev/null
     2>&1 > /dev/null
}

trap EXIT EXIT

#-----------------------------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------------------------------------------------------
iso_repository="https://cdimage.ubuntu.com/${flavour}/releases/${base}/release/"
iso_file=$(wget -q -O - "${iso_repository}" | grep -o "kubuntu-${base}.*amd64.iso" | head -n1)
url="https://cdimage.ubuntu.com/kubuntu/releases/${base}/release/${iso_file}"
#-----------------------------------------------------------------------------------------------------------------------------------------
script=$(readlink -f "${0}")
step_count=$(grep "^function" ${script} | grep -Ev "print-help|EXIT|function-template" | wc -l)
current_step=0
#-----------------------------------------------------------------------------------------------------------------------------------------
dependencies=(debootstrap mtools squashfs-tools xorriso casper lib32gcc-s1 grub-common grub-pc-bin grub-efi)
missing=""
for dep in ${dependencies[@]}; do
  dpkg -s ${dep} 2>/dev/null >/dev/null || {
    missing=" ${missing} ${dep}"
  }
done
#-----------------------------------------------------------------------------------------------------------------------------------------
mkdir -p debian-packages image/{boot/grub,casper,isolinux,preseed} ;
#-----------------------------------------------------------------------------------------------------------------------------------------

download-image
extract-image
mount-virtual-fs
chroot-phase-1
chroot-phase-2
chroot-phase-3
chroot-phase-4
chroot-phase-5
cleanup
umount-virtual-fs
build-squashfs
build-grub
build-iso

#-----------------------------------------------------------------------------------------------------------------------------------------

