#!/bin/bash
set -e

# ===== CONFIG =====
USERNAME="zomboyadmin"
USERPASS=""
TIMEZONE="Europe/Oslo"
HOSTNAME="archvm"
DISK="/dev/sda"   # Changed from vda to sda for Proxmox SCSI
# ==================

echo "Available disks:"
lsblk -d -o NAME,SIZE,TYPE | grep disk
echo "Current DISK setting: ${DISK}"
read -p "Press Enter to continue or Ctrl+C to abort..."

echo "[1/8] Partitioning disk..."
sgdisk -Z ${DISK}
sgdisk -n 1:0:0 -t 1:8300 ${DISK}

echo "[2/8] Formatting & mounting..."
mkfs.ext4 ${DISK}1
mount ${DISK}1 /mnt

echo "[3/8] Installing base system..."
pacstrap /mnt base linux linux-firmware vim sudo networkmanager xorg xorg-xwayland mesa \
wayland sway waybar wofi polkit-gnome hyprland kitty alacritty firefox nano git

echo "[4/8] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "[5/8] System configuration..."
arch-chroot /mnt /bin/bash <<EOF
# Timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Locale
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "${HOSTNAME}" > /etc/hostname
cat <<HOSTS >> /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

# Root password (empty by default - you should set USERPASS)
echo "root:${USERPASS}" | chpasswd

# Create user
useradd -m -G wheel -s /bin/bash ${USERNAME}
echo "${USERNAME}:${USERPASS}" | chpasswd

# Enable sudo for wheel group
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# Install and configure GRUB bootloader
pacman -S --noconfirm grub
grub-install --target=i386-pc ${DISK}
grub-mkconfig -o /boot/grub/grub.cfg

# Enable services
systemctl enable NetworkManager

EOF

echo "[6/8] Installation complete — unmounting..."
umount -R /mnt

echo "[7/8] Done! Reboot into Arch."
echo "[8/8] After reboot, login as ${USERNAME} and run 'Hyprland' to start the desktop."
echo ""
