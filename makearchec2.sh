#!/bin/bash
# 2010 Copyright Yejun Yang (yejunx AT gmail DOT com)
# Creative Commons Attribution-Noncommercial-Share Alike 3.0 United States License.
# http://creativecommons.org/licenses/by-nc-sa/3.0/us/

if [[ `uname -m` == i686 ]]; then
  ARCH=i686
  EC2_ARCH=i386
else
  ARCH=x86_64
  EC2_ARCH=x86_64
fi

ROOT=arch_$ARCH

PACKS="filesystem pacman sed coreutils ca-certificates groff \
        less which procps logrotate syslog-ng net-tools initscripts psmisc nano vi \
        iputils tar sudo mailx dhcpcd openssh kernel26-ec2 kernel26-ec2-headers \
        wget curl screen bash-completion ca-certificates kernel26-ec2 \
	kernel26-ec2-headers ec2-metadata btrfs-progs-git zsh ec2arch vim vimpager \
	vim-colorsamplerpack cpio dnsutils base-devel devtools srcpac abs \
	lesspipe ssmtp iproute2"

cat <<EOF > pacman.conf
[options]
HoldPkg     = pacman glibc
SyncFirst   = pacman
Architecture = $ARCH
[ec2]
Server = file:///root/repo
[core]
Include = /etc/pacman.d/mirrorlist
[extra]
Include = /etc/pacman.d/mirrorlist
[community]
Include = /etc/pacman.d/mirrorlist
EOF

LC_ALL=C mkarchroot -C pacman.conf $ROOT $PACKS

mv $ROOT/etc/pacman.d/mirrorlist $ROOT/etc/pacman.d/mirrorlist.pacorig
cat <<EOF >$ROOT/etc/pacman.d/mirrorlist
Server = http://mirrors.kernel.org/archlinux/\$repo/os/\$arch
Server = ftp://ftp.archlinux.org/\$repo/os/\$arch
EOF

chmod 666 $ROOT/dev/null
mknod -m 666 $ROOT/dev/random c 1 8
mknod -m 666 $ROOT/dev/urandom c 1 9
mkdir -m 755 $ROOT/dev/pts
mkdir -m 1777 $ROOT/dev/shm

mv $ROOT/etc/rc.conf $ROOT/etc/rc.conf.pacorig
cat <<EOF >$ROOT/etc/rc.conf
LOCALE="en_US.UTF-8"
TIMEZONE="UTC"
MOD_AUTOLOAD="no"
USECOLOR="yes"
USELVM="no"
DAEMONS=(syslog-ng sshd crond ec2)
EOF

mv $ROOT/etc/inittab $ROOT/etc/inittab.pacorig
cat <<EOF >$ROOT/etc/inittab
id:3:initdefault:
rc::sysinit:/etc/rc.sysinit
rs:S1:wait:/etc/rc.single
rm:2345:wait:/etc/rc.multi
rh:06:wait:/etc/rc.shutdown
su:S:wait:/sbin/sulogin -p
ca::ctrlaltdel:/sbin/shutdown -t3 -r now
EOF

mv $ROOT/etc/hosts.deny $ROOT/etc/hosts.deny.pacorig
cat <<EOF >$ROOT/etc/hosts.deny
#
# /etc/hosts.deny
#
# End of file
EOF

mkdir -p $ROOT/boot/boot/grub
cat <<EOF >$ROOT/boot/boot/grub/menu.lst
default 0
timeout 1

title  Arch Linux
	root   (hd0,0)
	kernel /vmlinuz26-ec2 root=/dev/xvda2 ip=dhcp spinlock=tickless ro
EOF

cd $ROOT/boot
ln -s boot/grub .
cd ../..

cp $ROOT/etc/ssh/sshd_config $ROOT/etc/ssh/sshd_config.pacorig
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/'  $ROOT/etc/ssh/sshd_config
sed -i 's/#UseDNS yes/UseDNS no/' $ROOT/etc/ssh/sshd_config

cp $ROOT/etc/nanorc $ROOT/etc/nanorc.pacorig
sed -i 's/^# include/include/' $ROOT/etc/nanorc
echo "set nowrap" >> $ROOT/etc/nanorc
echo "set softwrap" >> $ROOT/etc/nanorc

cp $ROOT/etc/skel/.bash* $ROOT/root
cp $ROOT/etc/skel/.screenrc $ROOT/root
mv $ROOT/etc/fstab $ROOT/etc/fstab.pacorig

cat <<EOF >$ROOT/etc/fstab
/dev/xvda2 /     auto    defaults,relatime 0 1
/dev/xvda1 /boot auto    defaults,noauto,relatime 0 0
/dev/xvdb /tmp  auto    defaults,relatime 0 0
/dev/xvda3 swap  swap   defaults 0 0
none      /proc proc    nodev,noexec,nosuid 0 0
none /dev/pts devpts defaults 0 0
none /dev/shm tmpfs nodev,nosuid 0 0
EOF

mv $ROOT/etc/makepkg.conf $ROOT/etc/makepkg.conf.pacorig
cp /etc/makepkg.conf $ROOT/etc/

mkdir $ROOT/opt/{sources,packages,srcpackages}
chmod 1777 $ROOT/opt/{sources,packages,srcpackages}

echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> $ROOT/etc/sudoers
sed -i 's/bash/zsh/' $ROOT/etc/passwd
curl -o $ROOT/root/.zshrc  "http://github.com/MrElendig/dotfiles-alice/raw/master/.zshrc"
curl -o $ROOT/root/.vimrc "http://github.com/MrElendig/dotfiles-alice/raw/master/.vimrc"

mv $ROOT/etc/resolv.conf $ROOT/etc/resolv.conf.pacorig
echo "nameserver 172.16.0.23" > $ROOT/etc/resolv.conf

touch $ROOT/root/firstboot
cp -a /root/repo $ROOT/root/
cp -a /var/cache/pacman/pkg/. $ROOT/var/cache/pacman/pkg/

#FILENAME=archlinux-$EC2_ARCH-$(date +%G%m%d).tar.xz
