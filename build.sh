#!/usr/bin/env bash

name="Mita-i_OS"
user="kurumin"
host="oka"
grub_name="Mita'i OS - Build $(date +%y.0.%-m-%-d)"
splash="quiet"
keyboard="br"
base="24.04"
system_dir="mita-i"
system_version="2025"

#-----------------------------------------------------------------------------------------------------------------------------------------
iso_repository="https://cdimage.ubuntu.com/kubuntu/releases/${base}/release/"
iso_file=$(wget -q -O - "${iso_repository}" | grep -o "kubuntu-${base}.*amd64.iso" | head -n1)
url="https://cdimage.ubuntu.com/kubuntu/releases/${base}/release/${iso_file}"
#-----------------------------------------------------------------------------------------------------------------------------------------

script=$(readlink -f "${0}")
step_count=$(grep "^function" ${script} | grep -Ev "print-help|EXIT|function-template" | wc -l)
current_step=0

#-----------------------------------------------------------------------------------------------------------------------------------------


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

    [ -d "rootfs/usr/share/plymouth/themes/kubuntu-logo" ] && {
        rm -rf "chroot/usr/share/plymouth/themes/kubuntu-logo"
        cp -rf "rootfs/usr/share/plymouth/themes/kubuntu-logo" "chroot/usr/share/plymouth/themes/"
    }

    # Fix permissions to /var/lib/apt/lists
    chroot "chroot" mkdir -p /var/lib/apt/lists
    chroot "chroot" sudo chown -R _apt:root /var/lib/apt/lists
    # Update casper and mark as manually installed if needed
    chroot "chroot" apt install casper  -y

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

    local kernel=$(chroot chroot/ dpkg -l | grep linux-image-.*-generic | cut -d' ' -f 3)
    chroot "chroot" apt install casper ${kernel} --reinstall --allow-downgrades -y
}

# Remove snaps and enable Flatpaks
function chroot-phase-2 {
    current_step=$((current_step+1))
    echo
    echo "---------------------------------------------------------"
    echo "  Step ${current_step}/${step_count} - Organize o sistema de arquivos" 
    echo "---------------------------------------------------------"
    
    [ -f "chroot/etc/TIGER_BUILD" ] && { return ; } || { echo ; }

    (
      system_dir="mita-i"
      system_version="2025"
      cd "chroot"
      mkdir -p "${system_dir}/system/"
      mkdir -p "${system_dir}/linux/"
      # Move /var to /usr
      mv var usr/state
      ln -s usr/state var
      # Move /root to /home
      mv root home
      ln -s home/root/ root

      # Rename /home as /users
      mv home/ users
      ln -s users home

      # Rename /tmp as /temp
      mv tmp temp
      ln -s temp tmp

      # Extract users data to outside of /etc
      mkdir .accounts
      mv etc/passwd .accounts
      mv etc/shadow .accounts
      mv etc/group .accounts
      mv etc/gshadow .accounts
      mv etc/login.defs .accounts
      ln -fs ../.accounts/passwd etc
      ln -fs ../.accounts/shadow etc
      ln -fs ../.accounts/group etc
      ln -fs ../.accounts/gshadow etc
      ln -fs ../.accounts/login.defs etc
      ln -fs "../../.accounts" "${system_dir}/system/"

      # Move /etc and /users-data to /usr
      mv etc usr/config
      ln -s usr/config etc
      ln -fs "../.accounts" "usr"
      ln -fs "../proc" "usr"
      ln -fs "../run" "usr"
      ln -fs "../lib/os-release" "etc"

      # Move /mnt to /media/0devices
      mv mnt media/0-devices
      ln -s media/0-devices mnt

      # Move usr to mita-i
      mkdir -p "${system_dir}/system"
      mv usr "${system_dir}/system/${system_version}"
      ln -s "${system_dir}/system/${system_version}" usr
      ls -s "../../proc" "${system_dir}/system/"
      ln -fs "../../run" "${system_dir}/system/"

      # Link linux kernel directories
      ln -fs /dev "${system_dir}/linux/devices"
      ln -fs /sys "${system_dir}/linux/kernel"
      ln -fs /run "${system_dir}/linux/runtime"
      ln -fs /proc "${system_dir}/linux/processes"

      mkdir -p applications
      mkdir -p containers

      mv opt applications/thirdparty
      ln -s applications/thirdparty opt

      # Link global flatpaks to /applications
      mkdir -p var/lib/flatpak/
      ln -s /applications var/lib/flatpak/app
      ln -s /containers var/lib/flatpak/runtime

      # Generate the .hidden file
      (
        echo "dev"
        echo "sys"
        echo "run"
        echo "proc"
        echo "etc"
        echo "home"
        echo "bin"
        echo "sbin"
        echo "lib"
        echo "lib64"
        echo "root"
        echo "tmp"
        echo "var"
        echo "mnt"
        echo "srv"
        echo "opt"
      ) > .hidden
    )
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

mkdir -p debian-packages rootfs image/{boot/grub,casper,isolinux,preseed} ;

download-image
extract-image
mount-virtual-fs
chroot-phase-1
umount-virtual-fs
build-squashfs
build-grub
build-iso
