#!/usr/bin/env bash
#
#  Build process functions
#
#-----------------------------------------------------------------------------------------------------------------------------------------
#
#  To extend the script place function on appropriate place based on the following boilerplate:
#
function function-template {
  show-header "Name of step"
  # Function body here, ${variant_data_dir} holds the variant
  # lists disrectory
}
#
#  Note: Functions are executed in the order of declaration.
#
#-----------------------------------------------------------------------------------------------------------------------------------------
function download-image {
    show-header "Download ISO image"

    mkdir -p base

    [ -f "base/${flavour}.iso" ] && {
      echo "The file is already fully retrieved; nothing to do."
      return;
    }

    (
      cd base
      wget --quiet --show-progress -c "${url}" -O "${flavour}.iso"
    )
}

function extract-image {
    show-header "Extract image"

    (
      cd base
      osirrox -indev "${flavour}.iso" -extract /casper .

      rm -f squashfs-root 
      rm -f filesystem.manifest
      rm -f filesystem.size
      rm -f filesystem.manifest-minimal-remove
      rm -f filesystem.manifest-remove
      rm -f filesystem.squashfs.gpg
    )
    echo
    mkdir -p chroot
    ln -s chroot/ squashfs-root
    unsquashfs -f base/filesystem.squashfs
    rm squashfs-root

    (
      cd "chroot"
      if [ -d "bin.usr-is-merged" ]; then
        rm -rf bin.usr-is-merged lib.usr-is-merged sbin.usr-is-merged
      fi
    )
}

function mount-virtual-fs {
    show-header "Initialize virtual FS"

    mkdir -p chroot/{dev/pts,run,proc,sys}

    --bind-mount
}

function prepare-base-image {
    show-header "Prepare base image" 

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
    chroot "chroot" ln -fs /etc/systemd/system/mita-i-etc-merge.service /etc/systemd/system/sysinit.target.wants/mita-i-etc-merge.service

    # Regenerate vmlinuz
    local kernel=$(chroot chroot/ dpkg -l | grep linux-image-.*-generic | cut -d' ' -f 3)
    chroot "chroot" apt update
    chroot "chroot" apt install casper ${kernel} --reinstall --allow-downgrades -y
}

function apply-mitai-root-structure {
    show-header "Apply Mita'i OS root structure" 

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
      if [ ! -L "boot" ]; then
        mv boot usr/grub
        ln -s usr/grub boot
      fi

      echo "  - Merge /var with /usr"
      if [ ! -L "var" ]; then
        mv var usr/state
        ln -s usr/state var
      fi

      echo "  - Merge /mnt with /media"
      if [ ! -L "mnt" ]; then
        mv mnt media/0-devices
        ln -s media/0-devices mnt
      fi

      echo "  - Merge /opt with applications/thirdparty"
      if [ ! -L "opt" ]; then
        mv opt applications/thirdparty
        ln -s applications/thirdparty opt
      fi

      echo "  - Merge Flatpak with /applications"
      if [ ! -L "${system_dir}/shared/flatpaks/runtime" ]; then
        mkdir -p "/${system_dir}/shared/flatpaks"
        ln -s "/${system_dir}/shared/flatpaks"  var/lib/flatpak
        ln -s /applications "${system_dir}/shared/flatpaks/app"
        ln -s /containers "${system_dir}/shared/flatpaks/runtime"
      fi

      echo "  - Move /usr to Mita'i OS directory"
      if [ ! -L "usr" ]; then
        mv usr "${system_dir}/versions/${system_version}"
        ln -s "${system_dir}/versions/${system_version}" usr
        ln -s /usr "${system_dir}/system"
        # /etc/resolv.conf é um link relativo
        ln -fs /run "${system_dir}/versions/${system_version}/run"
      fi

      echo "  - Rename /home as /users"
      if [ ! -L "home" ]; then
        mv home/ users
        ln -s users home
      fi

      echo "  - Merge /root with /users"
      if [ ! -L "root" ]; then
        mkdir -p home/root
        rm -rf root
        chown root:root home/root
        chmod 700 home/root
        ln -s home/root root
        chown root:root root
        chmod 700 root
      fi
    
      echo "  - Rename /tmp as /temp"
      if [ ! -L "tmp" ]; then
        mv tmp temp
        ln -s temp tmp
      fi


      echo "  - Populate Mita'i OS linux directory"
      if [ ! -L "${system_dir}/linux/processes" ]; then
        ln -fs /dev "${system_dir}/linux/devices"
        ln -fs /sys "${system_dir}/linux/kernel"
        ln -fs /run "${system_dir}/linux/runtime"
        ln -fs /proc "${system_dir}/linux/processes"
      fi


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

function remove-base-packages {
    show-header "Remove base packages" 

    # Remove snaps only to reduce ISO size, snaps are freinds :)
    rm -rf chroot/var/lib/snapd chroot/snap chroot/var/snap chroot/usr/lib/snapd
    mkdir -p chroot/var/lib/snapd chroot/var/snap chroot/usr/lib/snapd
    find chroot/etc/systemd -name "*snap*" -delete
    find chroot/etc/systemd -type d -name "*snap*" -exec rm -r {} +

    if [ "$(sed 's|#.*||g' "${variant_data_dir}/remove-packages.lst" | sed '/^$/d' | xargs)" = "" ]; then
      echo "No packages to remove"
      return
    fi
    chroot "chroot" apt autoremove --purge $(sed "s|#.*||g" "${variant_data_dir}/remove-packages.lst" | xargs) -y   
}

function install-debian-packages  {
    show-header "Install Debian packages outside repositories" 

    if [ "$(sed 's|#.*||g' "${variant_data_dir}/debian-packages-urls.lst" | sed '/^$/d' | xargs)" = "" ]; then
      echo "No Debian packages to install"
      return
    fi
    echo "  - Downloading packages"
    echo
    mkdir -p "chroot/mita-i.debian-packages"
    wget --quiet --show-progress -P "chroot/mita-i.debian-packages" $(sed "s|#.*||g" "${variant_data_dir}/debian-packages-urls.lst"  | sed '/^$/d' | xargs)
    echo

    echo "  - Installing packages"
    echo
    chroot chroot /bin/bash -c "apt install -y /mita-i.debian-packages/*.deb"
    echo

    echo "  - Remove .deb files"
    echo
    rm -rf "chroot/mita-i.debian-packages"
    echo
}

function install-system-packages {
    show-header "Install extra packages" 

    if [ "$(sed 's|#.*||g' "${variant_data_dir}/install-packages.lst" | sed '/^$/d' | xargs)" = "" ]; then
      echo "No packages to install"
      return
    fi
    chroot "chroot" apt install $(sed "s|#.*||g" "${variant_data_dir}/install-packages.lst" | xargs) -y
}

function install-flapak-packages  {
    show-header "Install Flatpak packages" 

    if [ "$(sed 's|#.*||g' "${variant_data_dir}/flatpaks.lst" | sed '/^$/d' | xargs)" = "" ]; then
      echo "No Flatpak packages to install"
      return
    fi
    echo "  - Checking for flatpak"
    if [ ! -f "chroot/usr/bin/flatpak" ]; then
        echo
        echo "Flatpak, not found, skipping..."
        echo
        return
    fi
    echo "  - Setup Flathub"
    echo
    echo "Fixing TSL issues with Flathub SSL on chroot..."
    chroot "chroot" apt install ca-certificates --reinstall --allow-downgrades -y
    echo
    chroot "chroot" flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    echo
    echo "  - Installing packages"
    echo
    chroot "chroot" flatpak install $(sed "s|#.*||g" "${variant_data_dir}/flatpaks.lst" | xargs) -y
    echo
}

function install-appimage-packages  {
    show-header "Install AppImage packages" 

    if [ "$(sed 's|#.*||g' "${variant_data_dir}/appimages-urls.lst" | sed '/^$/d' | xargs)" = "" ]; then
      echo "No AppImage packages to install"
      return
    fi
    echo "  - Checking for Mita-i-appimage-installer"
    if [ ! -f "chroot/usr/bin/mita-i-appimage-installer" ]; then
        echo
        echo "Mita-i-appimage-installer, not found skipping..."
        echo
        return
    fi

    echo "  - Installing packages"
    echo
    chroot "chroot" mita-i-appimage-installer fetch $(sed "s|#.*||g" "${variant_data_dir}/appimages-urls.lst" | xargs) -y
    echo
}

function install-snap-packages  {
    show-header "Install Snaps packages" 

    if [ "$(sed 's|#.*||g' "${variant_data_dir}/snaps.lst" | sed '/^$/d' | xargs)" = "" ]; then
      echo "No Snap packages to install"
      return
    fi
    echo "  - Checking for snapd"
    echo
    if [ ! -f "chroot/usr/bin/snap" ]; then
        echo
        echo "Snap support, not found skipping..."
        echo
    fi
    echo "  - Installing packages"
    echo
    chroot "chroot" snap install $(sed "s|#.*||g" "${variant_data_dir}/snaps.lst" | xargs) -y
    echo
}

function remove-packages-contents {
    show-header "Remove package contents" 

    mkdir -p chroot/etc/apt/preferences.d/

    if [ "$(sed 's|#.*||g' "${variant_data_dir}/remove-packages-content.lst" | xargs)" = "" ]; then
      echo "No packages to remove contents"
      return
    fi

    for package in $(sed "s|#.*||g" "${variant_data_dir}/remove-packages-content.lst" | xargs); do
      echo "Removing '${package}' content"
      for file in $(cat "chroot/var/lib/dpkg/info/${package}.list"); do
        if [ -f "chroot/${file}" ]; then
          rm "chroot/${file}"
        fi
      done

      echo "  - Regenerate list file"
      (
        echo "/."
        echo "/etc"
        echo "/etc/apt"
        echo "/etc/apt/preferences.d"
        echo "/etc/apt/preferences.d/${package}"
      ) > chroot/var/lib/dpkg/info/${package}.list
      echo "  - Pinning release"
      (
        echo "Package: ${package}"
        echo "Pin: release *"
        echo "Pin-Priority: -1"
      ) > chroot/etc/apt/preferences.d/${package}
      echo "  - Generating md5sum of '/etc/apt/preferences.d/${package}'"
      chroot chroot/ md5sum "etc/apt/preferences.d/${package}" > chroot/var/lib/dpkg/info/${package}.md5sums

      echo "  - Removing triggers"
      for trigger in conffiles postrm prerm postinst preinst shlibs triggers; do
        if [ -f "chroot/var/lib/dpkg/info/${package}.${trigger}" ]; then
          rm "chroot/var/lib/dpkg/info/${package}.${trigger}"
        fi
      done
    done 
    chroot chroot/ dpkg --clear-avail
    chroot chroot/ apt-get update
}

function cleanup-system-image {
    show-header "Clear the system image" 

    echo "  - Hide useless itens from menu"
    mkdir -p chroot/usr/local/share/applications
    for file in $(sed "s|#.*||g" "${variant_data_dir}/hide-from-menu.lst" | xargs); do
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
    show-header "Finish virtual FS" 

    echo "RESUME=none"   > "chroot/etc/initramfs-tools/conf.d/resume"
    echo "FRAMEBUFFER=y" > "chroot/etc/initramfs-tools/conf.d/splash"

    --bind-umount

    # Cleanup history and cache
    rm -rf chroot/tmp/*
    rm -rf chroot/debian-packages    || true 2>&1 > /dev/null
    rm -rf chroot/lib.usr-is-merged  || true 2>&1 > /dev/null
    rm -rf chroot/sbin.usr-is-merged || true 2>&1 > /dev/null
}

function build-squashfs {
    show-header "Compress system image"

    mkdir -pv image/{boot/grub,casper,isolinux,preseed}
    mksquashfs chroot image/casper/filesystem.squashfs -comp xz -noappend
}

function build-grub {
    show-header "Build GRUB image"

    cp --dereference chroot/boot/vmlinuz    image/casper/vmlinuz
    cp --dereference chroot/boot/initrd.img image/casper/initrd

    (
        sed "s|#.*||g" "${variant_data_dir}/grub-entries.yaml"  | sed '/^$/d' | sed 's|^|menuentry |;s|$|\n  initrd /casper/initrd\n}\n|;s|:| {\n  |'
        
        echo "menuentry \"Reboot\" {reboot}"
        echo "menuentry \"Shutdown\" {halt}"
        echo
    ) > image/boot/grub/loopback.cfg

    local escaped_user=$(printf '%s\n'           "$user"            | sed -e 's/[\/&]/\\&/g;s/"/\\"/g')
    local escaped_host=$(printf '%s\n'           "$host"            | sed -e 's/[\/&]/\\&/g;s/"/\\"/g')
    local escaped_name=$(printf '%s\n'           "$name"            | sed -e 's/[\/&]/\\&/g;s/"/\\"/g')
    local escaped_grub_name=$(printf '%s\n'      "$grub_name"       | sed -e 's/[\/&]/\\&/g;s/"/\\"/g')
    local escaped_splash=$(printf '%s\n'         "$splash"          | sed -e 's/[\/&]/\\&/g;s/"/\\"/g')
    local escaped_keyboard=$(printf '%s\n'       "$keyboard"        | sed -e 's/[\/&]/\\&/g;s/"/\\"/g')
    local escaped_base=$(printf '%s\n'           "$base"            | sed -e 's/[\/&]/\\&/g;s/"/\\"/g')
    local escaped_system_dir=$(printf '%s\n'     "$system_dir"      | sed -e 's/[\/&]/\\&/g;s/"/\\"/g')
    local escaped_system_version=$(printf '%s\n' "$system_version"  | sed -e 's/[\/&]/\\&/g;s/"/\\"/g')
    local escaped_flavour=$(printf '%s\n'        "$flavour"         | sed -e 's/[\/&]/\\&/g;s/"/\\"/g')
    local escaped_locale=$(printf '%s\n'         "$locale"          | sed -e 's/[\/&]/\\&/g;s/"/\\"/g')
    local escaped_timezone=$(printf '%s\n'       "$timezone"        | sed -e 's/[\/&]/\\&/g;s/"/\\"/g')

    sed -i \
      -e "s/\${user}/$escaped_user/g"                     \
      -e "s/\${host}/$escaped_host/g"                     \
      -e "s/\${name}/$escaped_name/g"                     \
      -e "s/\${grub_name}/\"$escaped_grub_name\"/g"           \
      -e "s/\${splash}/$escaped_splash/g"                 \
      -e "s/\${keyboard}/$escaped_keyboard/g"             \
      -e "s/\${base}/$escaped_base/g"                     \
      -e "s/\${system_dir}/$escaped_system_dir/g"         \
      -e "s/\${system_version}/$escaped_system_version/g" \
      -e "s/\${flavour}/$escaped_flavour/g"               \
      -e "s/\${locale}/$escaped_locale/g"                 \
      -e "s/\${timezone}/$escaped_timezone/g"             \
      image/boot/grub/loopback.cfg

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
    show-header "Generate ISO image"

    cd image
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
        echo "  ISO image file: "
        echo "    "$( du -sh "${ISO}")
        echo

        exit 0
    }

    echo "Failed to generate ISO"
    exit 1
}
#-----------------------------------------------------------------------------------------------------------------------------------------
function show-header {
    current_step=$((current_step+1))
    local progress="${current_step}/${step_count}"

    echo
    echo "---------------------------------------------------------------------"
    echo "  Step ${progress} - ${1}" 
    echo "---------------------------------------------------------------------"
    echo
}
#-----------------------------------------------------------------------------------------------------------------------------------------
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
function --bind-umount {
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
}
#-----------------------------------------------------------------------------------------------------------------------------------------
function --help  {
  d
}
function --bind-mount {
    echo "  - Mounting /dev"
    mount --bind /dev "chroot/dev"

    echo "  - Mounting /run"
    mount --bind /run "chroot/run"

    echo "  - Mounting /proc"
    chroot "chroot" mount none -t proc /proc

    echo "  - Mounting /dev/pts"
    chroot "chroot" mount none -t devpts /dev/pts
}
#-----------------------------------------------------------------------------------------------------------------------------------------
function --enter-chroot {
  show-header "Entering chroot now..."
  chroot "chroot"
}
#-----------------------------------------------------------------------------------------------------------------------------------------
script=$(readlink -f "${0}")
step_count=$(grep "^function" ${script} | grep -Ev -- "--help|EXIT|function-template|show-header|--enter-chroot" | wc -l)
current_step=0
#-----------------------------------------------------------------------------------------------------------------------------------------
if [ "$SUDO_USER" ] && [ "$USER" = "$SUDO_USER" ]; then
    echo "This is script was made to run as sudo -EH"
    exit 1
fi
#-----------------------------------------------------------------------------------------------------------------------------------------
dependencies=(debootstrap mtools squashfs-tools xorriso casper lib32gcc-s1 grub-common grub-pc-bin grub-efi)
missing=""
for dep in ${dependencies[@]}; do
  dpkg -s ${dep} 2>/dev/null >/dev/null || {
    missing=" ${missing} ${dep}"
  }
done
#-----------------------------------------------------------------------------------------------------------------------------------------
cd "$(dirname "$(readlink -f "${0}")")"
#-----------------------------------------------------------------------------------------------------------------------------------------
variant="${1}"

if [ ! -d "data" ]; then
  echo "Error: '${variant}' can't find 'data' directory"
  exit 1
fi

if echo "${variant}" | grep -qE '[ /]'; then
  echo "Error: '${variant}' can't contain spaces or /"
  exit 1
fi

if [ "${variant}" = "" ]; then
  echo "Warning: Variant not specified fallbacking to 'minimal'"
  variant="minimal"
fi

if [ ! -f "data/${variant}/distro.ini" ]; then
  echo "Error: 'data/${variant}/distro.ini' not found"
  exit 1
fi

variant_data_dir=$(readlink -f "./data/${variant}")
#-----------------------------------------------------------------------------------------------------------------------------------------
source "${variant_data_dir}/distro.ini"
#-----------------------------------------------------------------------------------------------------------------------------------------
iso_repository="https://cdimage.ubuntu.com/${flavour}/releases/${base}/release/"
iso_file=$(wget -q -O - "${iso_repository}" | grep -o "kubuntu-${base}.*amd64.iso" | head -n1)
url="https://cdimage.ubuntu.com/kubuntu/releases/${base}/release/${iso_file}"
#-----------------------------------------------------------------------------------------------------------------------------------------
mkdir -p ${variant}
cd ${variant}
mkdir -p iso chroot image/{boot/grub,casper,isolinux,preseed} ;
#-----------------------------------------------------------------------------------------------------------------------------------------
if [ "${2}" = "--help" ]; then
  --help has-variant
  exit
fi
#-----------------------------------------------------------------------------------------------------------------------------------------
if [ "${1}" = "--help" ]; then
  --help
  exit
fi
#-----------------------------------------------------------------------------------------------------------------------------------------
if [ ! "${2}" = "" ]; then
  option=$(grep '^function' "${script}" | grep -Ev "EXIT|function-template|show-header|--bind-.*|mount-virtual-fs" | cut -d' ' -f2 | grep -- ^"${2}"$)
  if [ ! "${option}" == "" ]; then
    step_count=3

    show-header "Initialize virtual FS"
    --bind-mount

    unset option
    eval "'$(grep '^function' "${script}" | grep -Ev 'EXIT|function-template|show-header|--bind-.*|mount-virtual-fs' | cut -d' ' -f2 | grep -- ^${2}$)'"

    show-header "Finish virtual FS" 
    --bind-umount

    echo
    exit
  fi
  echo "Unknown option '${2}' availables:"
  echo
  grep '^function' "${script}" | grep -Ev  -- "EXIT|function-template|show-header|--bind-.*|mount-virtual-fs" | cut -d' ' -f2  | grep "" | sort | sed 's|^|  * |'
  echo
  exit 1
fi
#-----------------------------------------------------------------------------------------------------------------------------------------
eval "$(grep '^function' ${script} | grep -Ev -- "^--|EXIT|function-template|show-header" | cut -d' ' -f2 | tr '\n' ';')"
#-----------------------------------------------------------------------------------------------------------------------------------------
