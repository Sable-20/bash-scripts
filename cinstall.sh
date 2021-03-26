#!/usr/bin/env bash

# return codes
SUCCESS=0
FAILURE=1

# colors
WHITE="$(tput setaf 7)"
# WHITEB="$(tput bold ; tput setaf 7)"
# BLUE="$(tput setaf 4)"
BLUEB="$(tput bold ; tput setaf 4)"
CYAN="$(tput setaf 6)"
CYANB="$(tput bold ; tput setaf 6)"
# GREEN="$(tput setaf 2)"
# GREENB="$(tput bold ; tput setaf 2)"
RED="$(tput setaf 1)"
# REDB="$(tput bold; tput setaf 1)"
YELLOW="$(tput setaf 3)"
# YELLOWB="$(tput bold ; tput setaf 3)"
BLINK="$(tput blink)"
NC="$(tput sgr0)"

columns="$(tput cols)"
str="--==[ arch installer ]==--"

printf "${BLUEB}%*s${NC}\n" "${COLUMNS:-$(tput cols)}" | tr ' ' '-'

echo "$str" |
while IFS= read -r line
do
    printf "%s%*s\n%s" "$CYANB" $(( (${#line} + columns) / 2)) \
    "$line" "$NC"
done

printf "${BLUEB}%*s${NC}\n\n\n" "${COLUMNS:-$(tput cols)}" | tr ' ' '-'

return $SUCCESS

echo "testing connection...."
test_ping=$(ping -c 3 https://www.gentoo.org)
echo $test_ping

if  $test_ping &> /dev/null
then
    echo "connected... continuing..."
    continue
else
    exit $FAILURE
fi

timedatectl set-ntp true
ntp_done=$(timedatectl status)
echo $ntp_done

echo "pausing for 1 minute..."
sleep 60s
$(clear)

detect_disks=$(lsblk)
echo $detect_disks

echo "You will need to make this a GPT partition table if the device is UEFI"
echo "dont forget to check the types"

sleep 5s

echo "make the first partition EFI partition"
echo "make the second partition swap partition"
echo "make the final partition root partition"


read -p "what disk would you like to use? " chosen_disk
fdisk "/dev/$chosen_disk"

clear

if [[ $chosen_disk =~ ^nvme ]]; then
    make_fat=$(mkfs.fat -F32 /dev/${chosen_disk}p1)
    echo $make_fat
    make_swap=$(mkswap /dev/${chosen_disk}p2)
    echo $make_swap
    turn_on_swap=$(swapon /dev/${chosen_disk}p2)
    echo $turn_on_swap
    make_root_fs=$(mkfs.ext4 /dev/${chosen_disk}p3)
    echo $make_root_fs
elif [[ $chosen_disk =~ ^sda ]]; then
    make_fat=$(mkfs.fat -F32 /dev/${chosen_disk}1)
    echo $make_fat
    make_swap=$(mkswap /dev/${chosen_disk}2)
    echo $make_swap
    turn_on_swap=$(swapon /dev/${chosen_disk}2)
    echo $turn_on_swap
    make_root_fs=$(mkfs.ext4 /dev/${chosen_disk}3)
    echo $make_root_fs
fi

echo "mounting root fs..."

if [[ $chosen_disk =~ ^nvme ]]; then
    mount_root=$(mount /dev/${chosen_disk}p3 /mnt)
elif [[ $chosen_disk =~ ^sda ]]; then
    mount_root=$(mount /dev/${chosen_disk}3 /mnt)
fi

echo "disk mounted..."

sleep 10s
echo "running pacstrap..."
sleep 3s
clear

run_pacstrap=$(pacstrap /mnt base linux linux-firmware)
echo $run_pacstrap

sleep 5s
clear

generate_fstab=$(genfstab -U /mnt >> /mnt/etc/fstab)
echo $generate_fstab

chroot_in=$(arch-chroot /mnt)
echo $chroot_in

read -p "Enter your REGION for timezone configuration" REGION
read -p "Enter your CITY for timezone configuration" CITY

set_tz=$(ln -sf /usr/share/zoneinfo/${REGION}/${CITY} /etc/localtime)
echo $set_tz

set_sys_clock=$(hwclock --systohc)
echo $set_sys_clock

# echo "installing nano..."

# install_editor=$(pacman -S nano --no-confirm)
# echo $install_editor

echo "enter locale"
echo " "

read -p "Enter your local in quotation makrs(ex: \"en_US.UTF-8 UTF-8\"" chosen_locale
echo $chosen_locale >> /etc/locale.gen

generate_locale=$(locale-gen)
echo $generate_locale

read -p "Enter hostname" chosen_hostname
echo $chosen_hostname > /etc/hostname

echo "editing hosts file..."
echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    ${chosen_hostname}.localdomain    ${chosen_hostname}" >> /etc/hosts

clear

read -sp "set the root password" root_passwd
echo "$root_passwd" | passwd

read -p "add a user?[y/n] " new_user

if [ $new_user == "y"] || [ $new_user == "Y" ];
then
    read -p "enter the name of the user" new_user_name
    useradd -m $new_user_name
    read -sp "enter the passwd for the new user" new_user_pass
    echo $new_user_pass | passwd $new_user_name
    echo "added"
    sleep 3
    echo "adding user to groups"
    add_groups=$(usermod -aG wheel,audio,video,optical,storage,sudo $new_user_name)
    echo $add_groups
    install_sudo=$(pacman -S sudo --noconfirm)
    echo $install_sudo
    sleep 2
    clear
    echo "adding user to the sudoers file"
    echo "$new_user_name ALL=(ALL) ALL" >> /etc/sudoers
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
    echo "%sudo ALL=(ALL) ALL" >> /etc/sudoers
fi

echo "installing grub..."
install_grub=$(pacman -S grub --no-confirm)
echo $install_grub

sleep 5s
clear

install_extra_tools=$(pacman -S efibootmgr dosfstools os-prober mtools --no-confirm)
echo $install_extra_tools

mkdir /boot/EFI

if [[ $chosen_disk =~ ^nvme ]]; then
    mount_efi=$(mount /dev/${chosen_disk}p1 /boot/EFI)
elif [[ $chosen_disk =~ ^sda ]]; then
    mount_efi=$(mount /dev/${chosen_disk}1 /boot/EFI)
fi

grub_install=$(grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck)
echo $grub_install

make_config=$(grub-mkconfig -o /boot/grub/grub.cfg)
echo $make_config

installing_extras=$(pacman -S vim nano networkmanager neofetch git --no-confirm)
echo $installing_extras

echo "enabling network manager..."
enable_network_mgr=$(systemctl enable --now NetworkManager)
echo $enable_network_mgr

sleep 3s
echo "exiting chroot...."

exit

echo "unmounting..."
unmounting=$(umount -l /mnt)
echo $unmounting