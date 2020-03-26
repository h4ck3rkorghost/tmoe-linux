#!/data/data/com.termux/files/usr/bin/bash
########################################################################
#检测架构 CHECK architecture
CheckArch() {

	case $(uname -m) in
	aarch64)
		archtype="arm64"
		;;
	arm64)
		archtype="arm64"
		;;
	armv8a)
		archtype="arm64"
		;;
	arm)
		archtype="armhf"
		;;
	armv7l)
		archtype="armhf"
		;;
	armhf)
		archtype="armhf"
		;;
	armv6l)
		archtype="armel"
		;;
	armel)
		archtype="armel"
		;;
	amd64)
		archtype="amd64"
		;;
	x86_64)
		archtype="amd64"
		;;
	i*86)
		archtype="i386"
		;;
	x86)
		archtype="i386"
		;;
	s390*)
		archtype="s390x"
		;;
	ppc*)
		archtype="ppc64el"
		;;
	mips*)
		archtype="mipsel"
		#echo -e 'Embedded devices such as routers are not supported at this time\n暂不支持mips架构的嵌入式设备'
		#20200323注：手动构建了mipsel架构的debian容器镜像，现在已经支持了。
		#exit 1
		;;
	risc*)
		archtype="riscv"
		#20200323注：riscv靠qemu实现跨cpu架构运行chroot容器
		#echo 'The RISC-V architecture you are using is too advanced and we do not support it yet.'
		#exit 1
		;;
	*)
		echo "未知的架构 $(uname -m) unknown architecture"
		exit 1
		;;
	esac
	DebianFolder=debian_${archtype}
	DebianCHROOT=${HOME}/${DebianFolder}
	YELLOW=$(printf '\033[33m')
	RESET=$(printf '\033[m')
	cur=$(pwd)
	ANDROIDVERSION=$(getprop ro.build.version.release 2>/dev/null) || ANDROIDVERSION=6

	autoCheck

}
#未来可能不会增加的功能:加入路由器(mipsel架构)支持，需要从软件源开始构建。
#路由器要把whiptail改成dialog，还要改一下opkg安装的依赖项目。
#########################################################
autoCheck() {

	if [ "$(uname -o)" = "Android" ]; then
		LINUXDISTRO='Android'
		termux-setup-storage
		ANDROIDTERMUX
	elif [ "$(uname -v | cut -c 1-3)" = "iSH" ]; then
		LINUXDISTRO='iSH'
		if grep -q 'cdn.alpinelinux.org' "/etc/apk/repositories"; then
			sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g'
		fi
		GNULINUX
	else
		GNULINUX
	fi
	##当检测到ish后一定要加上GNULINUX
}
########################################
GNULINUX() {
	if grep -q 'debian' '/etc/os-release'; then
		LINUXDISTRO='debian'

	elif grep -Eq "opkg|entware" '/opt/etc/opkg.conf' 2>/dev/null || grep -q 'openwrt' "/etc/os-release"; then
		LINUXDISTRO='openwrt'
		cd /tmp
		wget --no-check-certificate -qO "router-debian.bash" https://gitee.com/mo2/linux/raw/master/debian.sh
		chmod +x 'router-debian.bash'
		#bash -c "$(cat 'router-zsh.bash' |sed 's@/usr/bin@/opt/bin@g' |sed 's@-e /bin@-e /opt/bin@g' |sed 's@whiptail@dialog@g')"
		sed -i 's@/usr/bin@/opt/bin@g' 'router-debian.bash'
		sed -i 's@-e /bin@-e /opt/bin@g' 'router-debian.bash'
		sed -i 's@whiptail@dialog@g' 'router-debian.bash'
		sed -i 's@wget --no-check-certificate -qO "router-debian.bash"@#&@' 'router-debian.bash'
		sed -i 's@bash router-debian.bash@#&@' 'router-debian.bash'
		bash router-debian.bash

	elif grep -Eqi "Fedora|CentOS|Red Hat|redhat" '/etc/os-release'; then
		LINUXDISTRO='redhat'

	elif grep -q "Alpine" '/etc/issue' || grep -q "Alpine" '/etc/os-release'; then
		LINUXDISTRO='alpine'

	elif grep -Eq "Arch|Manjaro" '/etc/os-release'; then
		LINUXDISTRO='arch'

	elif grep -Eq "gentoo|funtoo" '/etc/os-release'; then
		LINUXDISTRO='gentoo'
	fi

	dependencies=""

	if [ ! -e /bin/tar ]; then
		if [ "${LINUXDISTRO}" = "gentoo" ]; then
			dependencies="${dependencies} app-arch/tar"
		else
			dependencies="${dependencies} tar"
		fi
	fi

	if [ ! -e /bin/grep ] && [ ! -e /usr/bin/grep ]; then
		if [ "${LINUXDISTRO}" = "gentoo" ]; then
			dependencies="${dependencies} sys-apps/grep"
		else
			dependencies="${dependencies} grep"
		fi
	fi

	if [ ! -e /usr/bin/pv ]; then
		if [ "${LINUXDISTRO}" = "gentoo" ]; then
			dependencies="${dependencies} sys-apps/pv"
		else
			dependencies="${dependencies} pv"
		fi
	fi

	if [ ! -e /usr/bin/proot ]; then
		if [ "${LINUXDISTRO}" = "debian" ]; then
			dependencies="${dependencies} proot"
		fi
	fi

	if [ ! -e /usr/bin/git ]; then
		if [ "${LINUXDISTRO}" = "openwrt" ]; then
			dependencies="${dependencies} git git-http"
		elif [ "${LINUXDISTRO}" = "gentoo" ]; then
			dependencies="${dependencies} dev-vcs/git"
		else
			dependencies="${dependencies} git"
		fi
	fi

	if [ ! -e /usr/bin/xz ]; then
		if [ "${LINUXDISTRO}" = "debian" ]; then
			dependencies="${dependencies} xz-utils"
		elif [ "${LINUXDISTRO}" = "gentoo" ]; then
			dependencies="${dependencies} app-arch/xz-utils"
		else
			dependencies="${dependencies} xz"
		fi
	fi

	if [ ! -e /usr/bin/whiptail ] && [ ! -e /bin/whiptail ]; then
		if [ "${LINUXDISTRO}" = "debian" ]; then
			dependencies="${dependencies} whiptail"
		elif [ "${LINUXDISTRO}" = "arch" ]; then
			dependencies="${dependencies} libnewt"
		elif [ "${LINUXDISTRO}" = "openwrt" ]; then
			dependencies="${dependencies} dialog"
		elif [ "${LINUXDISTRO}" = "gentoo" ]; then
			dependencies="${dependencies} dev-libs/newt"
		else
			dependencies="${dependencies} newt"
		fi
	fi

	if [ ! -e /usr/bin/pkill ]; then

		if [ "${LINUXDISTRO}" = "gentoo" ]; then
			dependencies="${dependencies} sys-process/procps"
		elif [ "${LINUXDISTRO}" != "openwrt" ]; then
			dependencies="${dependencies} procps"
		fi
	fi

	if [ ! -e /usr/bin/curl ]; then
		if [ "${LINUXDISTRO}" = "gentoo" ]; then
			dependencies="${dependencies} net-misc/curl"
		else
			dependencies="${dependencies} curl"
		fi
	fi

	if [ ! -e /usr/bin/aria2c ]; then
		if [ "${LINUXDISTRO}" = "gentoo" ]; then
			dependencies="${dependencies} net-misc/aria2"
		else
			dependencies="${dependencies} aria2"
		fi
	fi

	if [ ! -e "/usr/bin/less" ]; then
		if [ "${LINUXDISTRO}" = "gentoo" ]; then
			dependencies="${dependencies} sys-apps/less"
		else
			dependencies="${dependencies} less"
		fi
	fi

	if [ -L "/usr/bin/less" ]; then
		if [ "${LINUXDISTRO}" = "openwrt" ]; then
			dependencies="${dependencies} less"
		fi
	fi

	if [ ! -e /bin/bash ]; then
		if [ "${LINUXDISTRO}" = "alpine" ] || [ "${LINUXDISTRO}" = "openwrt" ]; then
			dependencies="${dependencies} bash"
		fi
	fi

	if [ "${archtype}" = "riscv" ]; then
		dependencies="${dependencies} qemu qemu-user-static debootstrap"
	fi

	if [ ! -z "$dependencies" ]; then
		echo "正在安装相关依赖..."
		if [ "$(id -u)" != "0" ]; then
			sudo bash -c "$(wget -qO- https://gitee.com/mo2/linux/raw/master/debian.sh)" ||
				sudo bash -c "$(curl -LfsS https://gitee.com/mo2/linux/raw/master/debian.sh)" ||
				sudo sh -c "$(wget --no-check-certificate -qO- https://gitee.com/mo2/linux/raw/master/debian.sh)"
		fi

		if [ "${LINUXDISTRO}" = "debian" ]; then
			apt update
			apt install -y ${dependencies}

		elif [ "${LINUXDISTRO}" = "alpine" ]; then
			apk update
			apk add -q ${dependencies}

		elif [ "${LINUXDISTRO}" = "arch" ]; then
			pacman -Syu --noconfirm ${dependencies}

		elif [ "${LINUXDISTRO}" = "redhat" ]; then
			dnf install -y ${dependencies} || yum install -y ${dependencies}

		elif [ "${LINUXDISTRO}" = "openwrt" ]; then
			#opkg update
			opkg install ${dependencies} || opkg install whiptail

		elif [ "${LINUXDISTRO}" = "gentoo" ]; then
			emerge -av ${dependencies}
		else
			apt update
			apt install -y ${dependencies} || port install ${dependencies} || zypper in ${dependencies} || guix package -i ${dependencies} || pkg install ${dependencies} || pkg_add ${dependencies} || pkgutil -i ${dependencies}

		fi

	fi

	if [ "${LINUXDISTRO}" = "openwrt" ]; then
		if [ -d "/opt/bin" ]; then
			PREFIX="/opt"
		else
			PREFIX=${HOME}
		fi
	else
		#PREFIX=/data/data/com.termux/files/usr
		PREFIX='/usr/local'
	fi

	if [ "$(uname -r | cut -d '-' -f 3)" = "Microsoft" ] || [ "$(uname -r | cut -d '-' -f 2)" = "microsoft" ]; then
		WSL="[WSL(win10的linux子系统)]"
		WINDOWSDISTRO='WSL'
		#/usr/local/bin/wsl-open
		if [ ! -e /usr/local/bin/wsl-open ] && [ ! -e usr/bin/wsl-open ]; then
			echo '检测到您使用的是WSL'
			if [ ! -e /usr/bin/npm ]; then
				echo '正在为您安装nodejs、npm和npm模块（wsl-open）...'
				apt install -y nodejs
				wget -O- https://npmjs.org/install.sh | bash
			fi
			npm install -g wsl-open
		fi
	else
		WSL=""
	fi

	if [ "${LINUXDISTRO}" = "debian" ]; then
		if (whiptail --title "您想要对这个小可爱做什么 " --yes-button "安装工具" --no-button "管理工具" --yesno "检测到您使用的是deb系linux ${WSL}您是想要启动software安装工具，还是system管理工具？ ♪(^∇^*) " 9 50); then
			bash -c "$(wget -qO- https://gitee.com/mo2/linux/raw/master/debian-gui-install.bash)"
			exit 0
		fi
	fi

	MainMenu
}
########################################
ANDROIDTERMUX() {
	dependencies=""

	if [ ! -e ${PREFIX}/bin/pv ]; then
		dependencies="${dependencies} pv"
	fi

	if [ ! -e ${PREFIX}/bin/termux-audio-info ]; then
		dependencies="${dependencies} termux-api"
	fi

	if [ ! -e ${PREFIX}/bin/pulseaudio ]; then
		dependencies="${dependencies} pulseaudio"
	fi

	if [ ! -e ${PREFIX}/bin/grep ]; then
		dependencies="${dependencies} grep"
	fi

	if [ ! -e ${PREFIX}/bin/aria2c ]; then
		dependencies="${dependencies} aria2"
	fi

	if [ ! -e ${PREFIX}/bin/proot ]; then
		dependencies="${dependencies} proot"
	fi

	if [ ! -e ${PREFIX}/bin/xz ]; then
		dependencies="${dependencies} xz-utils"
	fi

	if [ ! -e ${PREFIX}/bin/tar ]; then
		dependencies="${dependencies} tar"
	fi

	if [ ! -e ${PREFIX}/bin/whiptail ]; then
		dependencies="${dependencies} dialog"
	fi

	if [ ! -e ${PREFIX}/bin/pkill ]; then
		dependencies="${dependencies} procps"
	fi

	if [ ! -e ${PREFIX}/bin/curl ]; then
		dependencies="${dependencies} curl"
	fi

	if [ ! -z "$dependencies" ]; then
		if (("${ANDROIDVERSION}" >= '7')); then
			if ! grep -q '^deb.*edu.cn.*termux-packages-24' '/data/data/com.termux/files/usr/etc/apt/sources.list'; then
				echo "${YELLOW}检测到您当前使用的sources.list不是清华源,是否需要更换为清华源[Y/n]${RESET} "
				echo "更换后可以加快国内的下载速度,${YELLOW}按回车键确认，输n拒绝。${RESET}"
				echo "If you are not living in the People's Republic of China, then please type ${YELLOW}n${RESET} .[Y/n]"
				read opt
				case $opt in
				y* | Y* | "")
					TERMUXTUNASOURCESLIST
					;;
				n* | N*) echo "skipped." ;;
				*) echo "Invalid choice. skipped." ;;
				esac
			fi
		fi
		echo "正在安装相关依赖..."
		apt update
		apt install -y ${dependencies}
	fi
	##The vnc sound repair script from andronix has been slightly modified and optimized.
	if ! grep -q 'anonymous=1' ${HOME}/../usr/etc/pulse/default.pa; then
		sed -i '/auth-ip-acl/d' ${HOME}/../usr/etc/pulse/default.pa
		sed -i '/module-native-protocol-tcp/d' ${HOME}/../usr/etc/pulse/default.pa
		#grep -q "anonymous" ${HOME}/../usr/etc/pulse/default.pa
		echo "load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" >>${HOME}/../usr/etc/pulse/default.pa
	fi
	#auth-ip-acl=127.0.0.1;192.168.0.0/16时允许局域网内其它设备连接。
	#auth-ip-acl不能是localhost，可以是127.0.0.1或0.0.0.0
	if ! grep -q "exit-idle-time = -1" ${HOME}/../usr/etc/pulse/daemon.conf; then
		sed -i '/exit-idle/d' ${HOME}/../usr/etc/pulse/daemon.conf
		echo "exit-idle-time = -1" >>${HOME}/../usr/etc/pulse/daemon.conf
	fi
	#exit-idle-time 可设为180

	if [ -e ${DebianCHROOT}/root/.vnc/xstartup ]; then
		grep -q "PULSE_SERVER" ${DebianCHROOT}/root/.vnc/xstartup || sed -i '2 a\export PULSE_SERVER=127.0.0.1' ${DebianCHROOT}/root/.vnc/xstartup
	fi

	if [ -e ${PREFIX}/bin/debian ]; then
		grep -q "pulseaudio" ${PREFIX}/bin/debian || sed -i '2 a\pulseaudio --start' ${PREFIX}/bin/debian
	fi

	MainMenu
}

########################################################################
#-- 主菜单 main menu

MainMenu() {
	OPTION=$(
		whiptail --title "Tmoe-Debian GNU/Linux manager(20200323-17)" --backtitle "$(
			base64 -d <<-'DoYouWantToSeeWhatIsInside'
				6L6TZGViaWFuLWnlkK/liqjmnKznqIvluo8sVHlwZSBkZWJpYW4taSB0byBzdGFydCB0aGUgdG9v
				bCzokIzns7vnlJ/niannoJTnqbblkZgK
			DoYouWantToSeeWhatIsInside
		)" --menu "Please use the enter and arrow keys to operate.当前主菜单下有十几个选项,请使用方向键和回车键进行操作" 15 60 4 \
			"1" "proot安装 install debian" \
			"2" "chroot安装 debian" \
			"3" "Termux原系统gui及软件源" \
			"4" "novnc(web端控制)" \
			"5" "移除 remove system" \
			"6" "备份系统 backup system" \
			"7" "还原 restore" \
			"8" "查询空间占用 query space occupation" \
			"9" "更新本管理器 update debian manager" \
			"10" "配置zsh(优化termux) Configure zsh" \
			"11" "Download VNC apk" \
			"12" "VSCode Server arm64" \
			"13" "赋予proot容器真实root权限" \
			"14" "Video tutorial" \
			"0" "退出 exit" \
			3>&1 1>&2 2>&3
	)

	if [ "${OPTION}" == '1' ]; then
		if [ "$(uname -o)" != "Android" ]; then
			echo "非常抱歉，本功能仅适配安卓系统。"
			echo "Linux系统请换用chroot容器。"
			echo "Press enter to return。"
			echo "${YELLOW}按回车键返回。${RESET} "
			read
			MainMenu

		fi

		installDebian

	fi

	if [ "${OPTION}" == '2' ]; then
		if [ "$(uname -o)" = "Android" ]; then
			echo "非常抱歉，本功能仅适配Linux系统，暂未适配Android。"
			echo "Android系统请换用proot容器。"
			echo "由于在测试过程中出现部分已挂载的目录无法强制卸载的情况，故建议您换用proot容器。"
			echo "Press enter to return。"
			echo "${YELLOW}按回车键返回。${RESET} "
			read
			MainMenu
		else
			CHROOTINSTALLDebian
		fi

	fi

	if [ "${OPTION}" == '3' ]; then

		TERMUXINSTALLXFCE
	fi
	if [ "${OPTION}" == '4' ]; then

		INSTALLWEBNOVNC
	fi

	if [ "${OPTION}" == '5' ]; then

		REMOVESYSTEM

	fi

	if [ "${OPTION}" == '6' ]; then

		BackupSystem

	fi

	if [ "${OPTION}" == '7' ]; then

		RESTORESYSTEM

	fi

	if [ "${OPTION}" == '8' ]; then

		SpaceOccupation

	fi

	if [ "${OPTION}" == '9' ]; then

		UPDATEMANAGER
	fi

	if [ "${OPTION}" == '10' ]; then
		bash -c "$(curl -fLsS 'https://gitee.com/mo2/zsh/raw/master/zsh.sh')"

	fi

	if [ "${OPTION}" == '11' ]; then

		DOWNLOADVNCAPK

	fi

	if [ "${OPTION}" == '12' ]; then
		STARTVSCODE

	fi

	if [ "${OPTION}" == '13' ]; then

		RootMode
	fi

	if [ "${OPTION}" == '14' ]; then

		DownloadVideoTutorial
	fi

	if [ "${OPTION}" == '0' ]; then
		exit

	fi

}

########################################################################

installDebian() {
	if [ -d ~/${DebianFolder} ]; then
		if (whiptail --title "检测到您已安装debian,请选择您需要执行的操作！" --yes-button 'Start启动o(*￣▽￣*)o' --no-button 'Reinstall重装(っ °Д °)' --yesno "Debian has been installed, please choose what you need to do!" 7 60); then
			debian
		else

			echo "${YELLOW}检测到您已安装debian,是否重新安装？[Y/n]${RESET} "
			echo "${YELLOW}您可以无需输"y"，直接按回车键确认。${RESET} "
			echo "Detected that you have debian installed, do you want to reinstall it?[Y/n]"
			read opt
			case $opt in
			y* | Y* | "")
				bash ${PREFIX}/bin/debian-rm 2>/dev/null
				sed -i '/alias debian=/d' ${PREFIX}/etc/profile 2>/dev/null
				sed -i '/alias debian-rm=/d' ${PREFIX}/etc/profile 2>/dev/null
				source ${PREFIX}/etc/profile >/dev/null 2>&1
				INSTALLDEBIANORDOWNLOADRECOVERYTARXZ
				#bash -c "$(curl -fLsS 'https://gitee.com/mo2/linux/raw/master/installDebian.sh')"
				#bash -c "$(wget -qO- 'https://gitee.com/mo2/linux/raw/master/installDebian.sh')"
				;;
			n* | N*)
				echo "skipped."
				echo "Press enter to return。"
				echo "${YELLOW}按回车键返回。${RESET} "
				read
				MainMenu
				;;
			*)
				echo "Invalid choice. skipped."
				echo "Press enter to return。"
				echo "${YELLOW}按回车键返回。${RESET} "
				read
				MainMenu
				;;
			esac
		fi

	else
		INSTALLDEBIANORDOWNLOADRECOVERYTARXZ
		#bash -c "$(curl -fLsS 'https://gitee.com/mo2/linux/raw/master/installDebian.sh')"

	fi
}

########################################################################
#

RootMode() {
	if [ "$(uname -o)" != "Android" ]; then
		echo "非常抱歉，本功能仅适配安卓系统。"
		echo "chroot容器默认即为真实root权限。"
		echo "Press enter to return。"
		echo "${YELLOW}按回车键返回。${RESET} "
		read
		MainMenu
	fi

	if (whiptail --title "您真的要开启root模式吗" --yes-button '好哒o(*￣▽￣*)o' --no-button '不要(っ °Д °；)っ' --yesno "开启后将无法撤销，除非重装debian，建议您在开启前进行备份。若您的手机存在外置tf卡，则在开启后，会挂载整张卡。若无法备份和还原，请输tsudo debian-i启动本管理器。开启root模式后，绝对不要输破坏系统的危险命令！若在debian系统内输rm -rf /*删除根目录（格式化）命令，将有可能导致安卓原系统崩溃！！！请在本管理器内正常移除debian。" 10 60); then

		if [ ! -f ${PREFIX}/bin/tsu ]; then
			apt update
			apt install -y tsu
		fi
		if ! grep -q 'pulseaudio --system' ${PREFIX}/bin/debian; then
			sed -i '/pulseaudio/d' ${PREFIX}/bin/debian
			sed -i '2 a\pulseaudio --system --start' ${PREFIX}/bin/debian
		fi
		if ! grep -q 'tsudo touch' ${PREFIX}/bin/startvnc; then
			sed -i 's/^touch ~/tsudo &/' ${PREFIX}/bin/startvnc
			sed -i 's:/data/data/com.termux/files/usr/bin/debian:tsudo /data/data/com.termux/files/usr/bin/debian:' ${PREFIX}/bin/startvnc
		fi
		#上面那个是Termux专用的，勿改。

		mkdir -p /data/data/com.termux/files/usr/etc/storage/
		cd /data/data/com.termux/files/usr/etc/storage/

		rm -rf external-tf

		tsu -c 'ls /mnt/media_rw/*' 2>/dev/null || mkdir external-tf

		TFcardFolder=$(tsu -c 'ls /mnt/media_rw/| head -n 1')

		tsudo ln -s /mnt/media_rw/${TFcardFolder} ./external-tf

		sed -i 's:/home/storage/external-1:/usr/etc/storage/external-tf:g' ${PREFIX}/bin/debian

		cd ${PREFIX}/etc/
		if [ ! -f profile ]; then
			echo "" >>profile
		fi
		cp -pf profile profile.bak

		grep 'alias debian=' profile >/dev/null 2>&1 || sed -i '$ a\alias debian="tsudo debian"' profile
		grep 'alias debian-rm=' profile >/dev/null 2>&1 || sed -i '$ a\alias debian-rm="tsudo debian-rm"' profile

		source profile >/dev/null 2>&1
		alias debian="tsudo debian"
		alias debian-rm="tsudo debian-rm"
		if [ -d "${DebianCHROOT}/.vnc" ]; then
			tsudo chown root:root -R "${DebianCHROOT}/.vnc" 2>/dev/null || su -c "chown root:root -R ${DebianCHROOT}/.vnc"
		fi

		echo "You have modified debian to run with root privileges, this action will destabilize debian."
		echo "If you want to restore, please reinstall debian."
		echo "您已将debian修改为以root权限运行，如需还原，请重新安装debian。"
		echo "The next time you start debian, it will automatically run as root."
		echo "下次启动debian，将自动以root权限运行。"

		echo 'Debian will start automatically after 2 seconds.'
		echo '2s后将为您自动启动debian'
		echo 'If you do not need to display the task progress in the login interface, please manually add "#" (comment symbol) before the "ps -e" line in "~/.zshrc" or "~/.bashrc"'
		echo '如果您不需要在登录界面显示任务进程，请手动注释掉"~/.zshrc"里的"ps -e"'
		sleep 2
		tsudo debian
		MainMenu
		#############
	else
		MainMenu
	fi
	#不要忘记此处的fi
}
########################################################################
#
REMOVESYSTEM() {

	cd ~
	if [ -e "${DebianCHROOT}/etc/tmp/.ChrootInstallationDetectionFile" ]; then
		su -c "umount -lf ${DebianCHROOT}/dev >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/dev/shm  >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/dev/pts  >/dev/null 2>&1"
		su -c "	umount -lf ${DebianCHROOT}/proc  >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/sys  >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/tmp  >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/root/sd  >/dev/null 2>&1 "
		su -c "umount -lf ${DebianCHROOT}/root/tf  >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/root/termux >/dev/null 2>&1"
		ls -lah ${DebianCHROOT}/dev 2>/dev/null
		ls -lah ${DebianCHROOT}/dev/shm 2>/dev/null
		ls -lah ${DebianCHROOT}/dev/pts 2>/dev/null
		ls -lah ${DebianCHROOT}/proc 2>/dev/null
		ls -lah ${DebianCHROOT}/sys 2>/dev/null
		ls -lah ${DebianCHROOT}/tmp 2>/dev/null
		ls -lah ${DebianCHROOT}/root/sd 2>/dev/null
		ls -lah ${DebianCHROOT}/root/tf 2>/dev/null
		ls -lah ${DebianCHROOT}/root/termux 2>/dev/null
		df -h | grep debian
		echo '移除系统前，请先确保您已卸载chroot挂载目录。'
		echo '建议您在移除前进行备份，若因操作不当导致数据丢失，开发者概不负责！！！'
		echo "Before removing the system, make sure you have unmounted the chroot mount directory.
It is recommended that you back up the entire system before removal. If the data is lost due to improper operation, the developer is not responsible! "
	fi
	ps -e | grep proot
	ps -e | grep startvnc
	echo "移除系统前，请先确保您已停止debian容器。"
	pkill proot 2>/dev/null
	echo "若容器未停止运行，则建议你先手动在termux原系统中执行stopvnc，再进行移除操作。"
	echo 'Detecting Debian system footprint... 正在检测debian系统占用空间大小'
	du -sh ./${DebianFolder} --exclude=./${DebianFolder}/root/tf --exclude=./${DebianFolder}/root/sd --exclude=./${DebianFolder}/root/termux
	if [ ! -d ~/${DebianFolder} ]; then
		echo "${YELLOW}Detected that you are not currently installed 检测到您当前未安装debian${RESET}"
	fi
	echo "${YELLOW}按回车键确认移除,按Ctrl+C取消 Press enter to confirm.${RESET} "
	read

	chmod 777 -R ${DebianFolder}
	rm -rf "${DebianFolder}" ${PREFIX}/bin/debian ${PREFIX}/bin/startvnc ${PREFIX}/bin/stopvnc ${PREFIX}/bin/startxsdl ${PREFIX}/bin/debian-rm ${PREFIX}/bin/code 2>/dev/null || tsudo rm -rf "${DebianFolder}" ${PREFIX}/bin/debian ${PREFIX}/bin/startvnc ${PREFIX}/bin/stopvnc ${PREFIX}/bin/startxsdl ${PREFIX}/bin/debian-rm ${PREFIX}/bin/code 2>/dev/null
	sed -i '/alias debian=/d' ${PREFIX}/etc/profile
	sed -i '/alias debian-rm=/d' ${PREFIX}/etc/profile
	source profile >/dev/null 2>&1
	echo 'The debian system has been removed. If you want to uninstall aria2, enter "apt remove aria2" or "apt purge aria2"'
	echo '移除完成，如需卸载aria2,请手动输apt remove aria2'
	echo '其它相关依赖，如pv、dialog、procps、proot、wget等，均需手动卸载。'
	echo 'If you want to reinstall, it is not recommended to remove the image file.'
	echo '若需删除debian管理器，则请输rm -f ${PREFIX}/bin/debian-i'
	echo "${YELLOW}若您需要重装debian，则不建议删除镜像文件。${RESET} "
	ls -lh ~/debian-sid-rootfs.tar.xz 2>/dev/null
	ls -lh ~/debian-buster-rootfs.tar.xz 2>/dev/null
	ls -lh ~/ubuntu-focal-rootfs.tar.xz 2>/dev/null
	ls -lh ~/kali-rolling-rootfs.tar.xz 2>/dev/null
	ls -lh ~/funtoo-1.3-rootfs.tar.xz 2>/dev/null
	echo "${YELLOW}请问您是否需要删除镜像文件？[Y/n]${RESET} "
	echo 'Do you need to delete the image file (debian-sid-rootfs.tar.xz)?[Y/n]'

	read opt
	case $opt in
	y* | Y* | "")
		rm -vf ~/debian-sid-rootfs.tar.xz ${PREFIX}/bin/debian-rm 2>/dev/null
		rm -vf ~/debian-buster-rootfs.tar.xz 2>/dev/null
		rm -vf ~/ubuntu-focal-rootfs.tar.xz 2>/dev/null
		rm -vf ~/kali-rolling-rootfs.tar.xz 2>/dev/null
		rm -vf ~/funtoo-1.3-rootfs.tar.xz 2>/dev/null
		echo "Deleted已删除"
		;;
	n* | N*) echo "${YELLOW}Skipped,已跳过，按回车键返回。${RESET} " ;;
	*) echo "${YELLOW}Invalid choice，skipped.已跳过，按回车键返回。${RESET} " ;;
	esac
	MainMenu

}
########################################################################
#
BackupSystem() {
	if [ -e "${DebianCHROOT}/etc/tmp/.ChrootInstallationDetectionFile" ]; then
		su -c "umount -lf ${DebianCHROOT}/dev >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/dev/shm  >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/dev/pts  >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/proc  >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/sys  >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/tmp  >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/root/sd  >/dev/null 2>&1 "
		su -c "umount -lf ${DebianCHROOT}/root/tf  >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/root/termux >/dev/null 2>&1"
	fi
	OPTION=$(whiptail --title "Backup System" --menu "Choose your option" 15 60 4 \
		"0" "Back to the main menu 返回主菜单" \
		"1" "备份Debian" \
		"2" "备份Termux" \
		3>&1 1>&2 2>&3)
	###########################################################################
	if [ "${OPTION}" == '1' ]; then
		if [ ! -d /sdcard/Download/backup ]; then
			mkdir -p /sdcard/Download/backup && cd /sdcard/Download/backup
		else
			cd /sdcard/Download/backup
		fi

		ls -lth ./debian*.tar.* 2>/dev/null && echo '您之前所备份的(部分)文件如上所示'

		echo "${YELLOW}按回车键选择压缩类型 Press enter to select compression type${RESET} "
		read

		echo $(date +%Y-%m-%d_%H-%M) >backuptime.tmp
		TMPtime=debian_$(cat backuptime.tmp)

		if (whiptail --title "Select compression type 选择压缩类型 " --yes-button "tar.xz" --no-button "tar.gz" --yesno "Which do yo like better? \n tar.xz压缩率高，但速度慢。tar.xz has a higher compression ration, but is slower.\n tar.gz速度快,但压缩率低。tar.gz compresses faster, but with a lower compression ratio.\n 压缩过程中，进度条倒着跑是正常现象。" 12 50); then

			echo "您选择了tar.xz,即将为您备份至/sdcard/Download/backup/${TMPtime}.tar.xz"
			echo "${YELLOW}按回车键开始备份,按Ctrl+C取消。Press Enter to start the backup.${RESET} "
			read
			tar -PJpcvf ${TMPtime}.tar.xz --exclude=~/${DebianFolder}/root/sd --exclude=~/${DebianFolder}/root/tf --exclude=~/${DebianFolder}/root/termux ~/${DebianFolder} ${PREFIX}/bin/debian ${PREFIX}/bin/startvnc ${PREFIX}/bin/stopvnc
			#whiptail进度条已弃用
			#tar -PJpcf - --exclude=~/${DebianFolder}/root/sd --exclude=~/${DebianFolder}/root/tf --exclude=~/${DebianFolder}/root/termux ~/${DebianFolder} ${PREFIX}/bin/debian | (pv -n >${TMPtime}.tar.xz) 2>&1 | whiptail --gauge "Packaging into tar.xz" 10 70

			#xz -z -T0 -e -9 -f -v ${TMPtime}.tar
			echo "Don't worry too much, it is normal for some directories to backup without permission."
			echo "部分目录无权限备份是正常现象。"
			rm -f backuptime.tmp
			pwd
			ls -lth ./*tar* | grep ^- | head -n 1
			echo '备份完成,按回车键返回。'
			read
			MainMenu

		else

			echo "您选择了tar.gz,即将为您备份至/sdcard/Download/backup/${TMPtime}.tar.gz"
			echo "${YELLOW}按回车键开始备份,按Ctrl+C取消。Press Enter to start the backup.${RESET} "
			read

			tar -Ppczf - --exclude=~/${DebianFolder}/root/sd --exclude=~/${DebianFolder}/root/tf --exclude=~/${DebianFolder}/root/termux ~/${DebianFolder} ${PREFIX}/bin/debian ${PREFIX}/bin/startvnc ${PREFIX}/bin/stopvnc | (pv -p --timer --rate --bytes >${TMPtime}.tar.gz)

			#最新版弃用了whiptail的进度条！！！
			#tar -Ppczf - --exclude=~/${DebianFolder}/root/sd --exclude=~/${DebianFolder}/root/tf --exclude=~/${DebianFolder}/root/termux ~/${DebianFolder} ${PREFIX}/bin/debian | (pv -n >${TMPtime}.tar.gz) 2>&1 | whiptail --gauge "Packaging into tar.gz \n正在打包成tar.gz" 10 70

			echo "Don't worry too much, it is normal for some directories to backup without permission."
			echo "部分目录无权限备份是正常现象。"
			rm -f backuptime.tmp
			#  whiptail --gauge "正在备份,可能需要几分钟的时间请稍后.........." 6 60 0
			pwd
			ls -lth ./*tar* | grep ^- | head -n 1
			echo 'gzip压缩至60%完成是正常现象。'
			echo '备份完成,按回车键返回。'
			read
			MainMenu
		fi
	fi
	###################
	if [ "${OPTION}" == '2' ]; then
		BACKUPTERMUX

	fi

	##########################################
	if [ "${OPTION}" == '0' ]; then

		MainMenu
	fi
	MainMenu
}

BACKUPTERMUX() {
	TERMUXBACKUP=$(whiptail --title "多项选择题" --checklist \
		"您想要备份哪个目录？按空格键选择，*为选中状态，回车键确认 \n Which directory do you want to backup? Please press the space to select and press Enter to confirm." 15 60 4 \
		"home" "Termux主目录,主要用来保存用户文件" ON \
		"usr" "保存软件、命令和其它东西" OFF \
		3>&1 1>&2 2>&3)

	#####################################
	#$TERMUXBACKUP=$(whiptail --title "选择您需要备份的目录" --menu "Choose your $TERMUXBACKUP" 15 60 4 \
	#"0" "Back to previous menu 返回上层菜单" \
	#"1" "备份home目录" \
	#"2" "备份usr目录 " \
	#"3" "我全都要" \
	#3>&1 1>&2 2>&3)'
	##########################
	if [ "$TERMUXBACKUP" == 'home' ]; then

		if [ ! -d /sdcard/Download/backup ]; then
			mkdir -p /sdcard/Download/backup && cd /sdcard/Download/backup
		else
			cd /sdcard/Download/backup
		fi

		##tar -czf - ~/${DebianFolder} | (pv -p --timer --rate --bytes > ${TMPtime}.tar.gz)

		ls -lth ./termux-home*.tar.* 2>/dev/null && echo '您之前所备份的(部分)文件如上所示'

		#echo 'This operation will only backup the home directory of termux, not the debian system. If you need to backup debian, please select both options or backup debian separately.'
		#echo '本次操作将只备份termux的主目录，不包含主目录下的debian系统。如您需备份debian,请同时选择home和usr，或单独备份debian。'

		echo "${YELLOW}按回车键选择压缩类型 Press enter to select compression type${RESET} "
		read

		echo $(date +%Y-%m-%d_%H-%M) >backuptime.tmp
		TMPtime=termux-home_$(cat backuptime.tmp)

		if (whiptail --title "Select compression type 选择压缩类型 " --yes-button "tar.xz" --no-button "tar.gz" --yesno "Which do yo like better? \n tar.xz压缩率高，但速度慢。tar.xz has a higher compression ration, but is slower.\n tar.gz速度快,但压缩率低。tar.gz compresses faster, but with a lower compression ratio.\n 压缩过程中，进度条倒着跑是正常现象。" 10 60); then

			echo "您选择了tar.xz,即将为您备份至/sdcard/Download/backup/${TMPtime}.tar.xz"
			echo "${YELLOW}按回车键开始备份,按Ctrl+C取消。Press Enter to start the backup.${RESET} "
			read

			tar -PJpvcf ${TMPtime}.tar.xz --exclude=/data/data/com.termux/files/home/${DebianFolder}/root/sd --exclude=/data/data/com.termux/files/home/${DebianFolder}/root/termux --exclude=/data/data/com.termux/files/home/${DebianFolder}/root/tf /data/data/com.termux/files/home

			#xz -z -T0 -e -9 -v ${TMPtime}.tar

			echo "Don't worry too much, it is normal for some directories to backup without permission."
			echo "部分目录无权限备份是正常现象。"
			rm -f backuptime.tmp
			pwd
			ls -lth ./termux-home*tar* | grep ^- | head -n 1
			echo '备份完成,按回车键返回。'
			read
			MainMenu

		else

			echo "您选择了tar.gz,即将为您备份至/sdcard/Download/backup/${TMPtime}.tar.gz"
			echo "${YELLOW}按回车键开始备份,按Ctrl+C取消。Press Enter to start the backup.${RESET} "
			read

			tar -Ppvczf ${TMPtime}.tar.gz --exclude=/data/data/com.termux/files/home/${DebianFolder}/root/sd --exclude=/data/data/com.termux/files/home/${DebianFolder}/root/termux --exclude=/data/data/com.termux/files/home/${DebianFolder}/root/tf /data/data/com.termux/files/home

			echo "Don't worry too much, it is normal for some directories to backup without permission."
			echo "部分目录无权限备份是正常现象。"
			rm -f backuptime.tmp
			#  whiptail --gauge "正在备份,可能需要几分钟的时间请稍后.........." 6 60 0
			pwd
			ls -lth ./termux-home*tar* | grep ^- | head -n 1
			echo '备份完成,按回车键返回。'
			read
			MainMenu
		fi

	fi

	##########################
	if [ "$TERMUXBACKUP" == 'usr' ]; then

		if [ ! -d /sdcard/Download/backup ]; then
			mkdir -p /sdcard/Download/backup && cd /sdcard/Download/backup
		else
			cd /sdcard/Download/backup
		fi

		ls -lth ./termux-usr*.tar.* 2>/dev/null && echo '您之前所备份的(部分)文件如上所示'

		echo "${YELLOW}按回车键选择压缩类型 Press enter to select compression type${RESET} "
		read

		echo $(date +%Y-%m-%d_%H-%M) >backuptime.tmp
		TMPtime=termux-usr_$(cat backuptime.tmp)

		if (whiptail --title "Select compression type 选择压缩类型 " --yes-button "tar.xz" --no-button "tar.gz" --yesno "Which do yo like better? \n tar.xz压缩率高，但速度慢。tar.xz has a higher compression ration, but is slower.\n tar.gz速度快,但压缩率低。tar.gz compresses faster, but with a lower compression ratio.\n 压缩过程中，进度条倒着跑是正常现象。" 10 60); then

			echo "您选择了tar.xz,即将为您备份至/sdcard/Download/backup/${TMPtime}.tar.xz"
			echo "${YELLOW}按回车键开始备份,按Ctrl+C取消。Press Enter to start the backup.${RESET} "
			read

			#tar -PJpcf ${TMPtime}.tar /data/data/com.termux/files/usr
			echo '正在压缩成tar.xz'
			tar -PJpcf - /data/data/com.termux/files/usr | (pv -p --timer --rate --bytes >${TMPtime}.tar.xz)
			#echo '正在压缩成xz'
			#xz -z -T0 -e -9 -v ${TMPtime}.tar

			echo "Don't worry too much, it is normal for some directories to backup without permission."
			echo "部分目录无权限备份是正常现象。"
			rm -f backuptime.tmp
			pwd
			ls -lth ./termux-usr*tar* | grep ^- | head -n 1
			echo '备份完成,按回车键返回。'
			read
			MainMenu

		else

			echo "您选择了tar.gz,即将为您备份至/sdcard/Download/backup/${TMPtime}.tar.gz"
			echo "${YELLOW}按回车键开始备份,按Ctrl+C取消。Press Enter to start the backup.${RESET} "
			read

			#tar -Ppczf ${TMPtime}.tar.gz   /data/data/com.termux/files/usr
			tar -Ppczf - /data/data/com.termux/files/usr | (pv -p --timer --rate --bytes >${TMPtime}.tar.gz)
			##tar -czf - ~/${DebianFolder} | (pv -p --timer --rate --bytes > ${TMPtime}.tar.gz)

			echo "Don't worry too much, it is normal for some directories to backup without permission."
			echo "部分目录无权限备份是正常现象。"
			rm -f backuptime.tmp
			#  whiptail --gauge "正在备份,可能需要几分钟的时间请稍后.........." 6 60 0
			pwd
			ls -lth ./*tar* | grep ^- | head -n 1
			echo '备份完成,按回车键返回。'
			read
			MainMenu
		fi

	fi

	##########################
	if [ "$TERMUXBACKUP" == 'home usr' ]; then

		if [ ! -d /sdcard/Download/backup ]; then
			mkdir -p /sdcard/Download/backup && cd /sdcard/Download/backup
		else
			cd /sdcard/Download/backup
		fi

		ls -lth ./termux-home+usr*.tar.* 2>/dev/null && echo '您之前所备份的(部分)文件如上所示'

		echo "${YELLOW}按回车键选择压缩类型 Press enter to select compression type${RESET} "
		read

		echo $(date +%Y-%m-%d_%H-%M) >backuptime.tmp
		TMPtime=termux-home+usr_$(cat backuptime.tmp)

		if (whiptail --title "Select compression type 选择压缩类型 " --yes-button "tar.xz" --no-button "tar.gz" --yesno "Which do yo like better? \n tar.xz压缩率高，但速度慢。tar.xz has a higher compression ratio, but is slower.\n tar.gz速度快,但压缩率低。tar.gz compresses faster, but with a lower compression ratio.\n 压缩过程中，进度条倒着跑是正常现象。" 10 60); then
			echo "您选择了tar.xz,即将为您备份至/sdcard/Download/backup/${TMPtime}.tar.xz"
			echo "${YELLOW}按回车键开始备份,按Ctrl+C取消。Press Enter to start the backup.${RESET} "
			read

			#tar -PJpcf ${TMPtime}.tar /data/data/com.termux/files/usr
			echo '正在压缩成tar.xz'
			tar -PJpcf - /data/data/com.termux/files/home /data/data/com.termux/files/usr | (pv -p --timer --rate --bytes >${TMPtime}.tar.xz)
			#echo '正在压缩成xz'
			#xz -z -T0 -e -9 -v ${TMPtime}.tar

			echo "Don't worry too much, it is normal for some directories to backup without permission."
			echo "部分目录无权限备份是正常现象。"
			rm -f backuptime.tmp
			pwd
			ls -lth ./termux-home+usr*tar* | grep ^- | head -n 1
			echo '备份完成,按回车键返回。'
			read
			MainMenu

		else

			echo "您选择了tar.gz,即将为您备份至/sdcard/Download/backup/${TMPtime}.tar.gz"
			echo "${YELLOW}按回车键开始备份,按Ctrl+C取消。Press Enter to start the backup.${RESET} "
			read

			#tar -Ppczf ${TMPtime}.tar.gz   /data/data/com.termux/files/usr
			tar -Ppczf - /data/data/com.termux/files/home /data/data/com.termux/files/usr | (pv -p --timer --rate --bytes >${TMPtime}.tar.gz)
			##tar -czf - ~/${DebianFolder} | (pv -p --timer --rate --bytes > ${TMPtime}.tar.gz)

			echo "Don't worry too much, it is normal for some directories to backup without permission."
			echo "部分目录无权限备份是正常现象。"
			rm -f backuptime.tmp
			#  whiptail --gauge "正在备份,可能需要几分钟的时间请稍后.........." 6 60 0
			pwd
			ls -lth ./termux-home+usr*tar* | grep ^- | head -n 1
			echo '备份完成,按回车键返回。'
			read
			MainMenu
		fi

	fi

	################################
	if [ $exitstatus = 1 ]; then
		BackupSystem

	fi

}

########################################################################
#
RESTORESYSTEM() {
	if [ -e "${DebianCHROOT}/etc/tmp/.ChrootInstallationDetectionFile" ]; then
		su -c "umount -lf ${DebianCHROOT}/dev >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/dev/shm  >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/dev/pts  >/dev/null 2>&1"
		su -c "	umount -lf ${DebianCHROOT}/proc  >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/sys  >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/tmp  >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/root/sd  >/dev/null 2>&1 "
		su -c "umount -lf ${DebianCHROOT}/root/tf  >/dev/null 2>&1"
		su -c "umount -lf ${DebianCHROOT}/root/termux >/dev/null 2>&1"
	fi
	OPTION=$(whiptail --title "Restore System" --menu "Choose your option" 15 60 4 \
		"0" "Back to the main menu 返回主菜单" \
		"1" "Restore the latest debian backup 还原Debian" \
		"2" "Restore the latest termux backup 还原Termux" \
		3>&1 1>&2 2>&3)
	###########################################################################
	if [ "${OPTION}" == '1' ]; then
		cd /sdcard/Download/backup
		ls -lth debian*tar* | head -n 10 2>/dev/null || echo '未检测到备份文件'

		echo '目前仅支持还原最新的备份，如需还原旧版，请手动输以下命令'

		echo 'cd /sdcard/Download/backup ;ls ; tar -JPxvf 文件名.tar.xz 或 tar -Pzxvf 文件名.tar.gz'
		echo '请注意大小写，并把文件名改成具体名称'

		RESTORE=$(ls -lth ./debian*tar* | grep ^- | head -n 1 | cut -d '/' -f 2)
		echo " "
		ls -lh ${RESTORE}
		printf "${YELLOW}即将为您还原${RESTORE}，请问是否确认？[Y/n]${RESET} "
		#printf之后分行
		echo ''
		echo 'Do you want to restore it?[Y/n]'

		read opt
		case $opt in
		y* | Y* | "")

			#0-6是截取字符
			if [ "${RESTORE:0-6:6}" == 'tar.xz' ]; then
				echo 'tar.xz'
				pv ${RESTORE} | tar -PJx
			fi

			if [ "${RESTORE:0-6:6}" == 'tar.gz' ]; then
				echo 'tar.gz'
				pv ${RESTORE} | tar -Pzx
			fi

			;;

		\
			\
			n* | N*) echo "skipped." ;;
		*) echo "Invalid choice. skipped." ;;

			#tar xfv $pathTar -C $path
			#(pv -n $pathTar | tar xfv $pathTar -C $path ) 2>&1 | dialog --gauge "Extracting file..." 6 50

		esac

		echo "${YELLOW}按回车键返回。Press enter to return.${RESET}"
		read
		MainMenu

	fi

	###################
	if [ "${OPTION}" == '2' ]; then

		cd /sdcard/Download/backup
		ls -lth termux*tar* 2>/dev/null || echo '未检测到备份文件' | head -n 10

		echo '目前仅支持还原最新的备份，如需还原旧版，请手动输以下命令'

		echo 'cd /sdcard/Download/backup ;ls ; tar -JPxvf 文件名.tar.xz 或 tar -Pzxvf 文件名.tar.gz'
		echo '请注意大小写，并把文件名改成具体名称'

		RESTORE=$(ls -lth ./termux*tar* | grep ^- | head -n 1 | cut -d '/' -f 2)
		echo " "
		ls -lh ${RESTORE}
		printf "${YELLOW}即将为您还原${RESTORE}，请问是否确认？[Y/n]${RESET} "
		#printf之后分行
		echo ''
		echo 'Do you want to restore it?[Y/n]'

		read opt
		case $opt in
		y* | Y* | "")

			if [ "${RESTORE:0-6:6}" == 'tar.xz' ]; then
				echo 'tar.xz'
				pv ${RESTORE} | tar -PJx
			fi

			if [ "${RESTORE:0-6:6}" == 'tar.gz' ]; then
				echo 'tar.gz'
				pv ${RESTORE} | tar -Pzx
			fi

			;;

		\
			\
			n* | N*) echo "skipped." ;;
		*) echo "Invalid choice. skipped." ;;

			#tar xfv $pathTar -C $path
			#(pv -n $pathTar | tar xfv $pathTar -C $path ) 2>&1 | dialog --gauge "Extracting file..." 6 50

		esac

		echo "${YELLOW}按回车键返回。Press enter to return.${RESET}"
		read
		MainMenu

	fi

	#####################################
	if [ "${OPTION}" == '0' ]; then

		MainMenu
	fi
	MainMenu
}

########################################################################
SpaceOccupation() {
	cd ~/..
	OPTION=$(whiptail --title "Query space occupation ranking" --menu "查询空间占用排行" 15 60 4 \
		"0" "Back to the main menu 返回主菜单" \
		"1" "termux各目录" \
		"2" "termux文件" \
		"3" "sdcard" \
		"4" "总存储空间用量Disk usage" \
		3>&1 1>&2 2>&3)
	###########################################################################
	#echo "${YELLOW}2333333333${RESET}"
	if [ "${OPTION}" == '1' ]; then
		echo '正在加载中，可能需要几秒钟时间，加载时间取决于文件数量和闪存读写速度。'
		echo 'Loading may take several seconds, depending on the number of files and the UFS or emmc flash read and write speed.'
		echo "${YELLOW}主目录 TOP15${RESET}"

		du -hsx ./home/* ./home/.* 2>/dev/null | sort -rh | head -n 15

		echo ''

		echo "${YELLOW}usr 目录 TOP6${RESET}"

		du -hsx ./usr/* 2>/dev/null | sort -rh | head -n 6

		echo ''

		echo "${YELLOW}usr/lib 目录 TOP8${RESET}"

		du -hsx ./usr/lib/* 2>/dev/null | sort -rh | head -n 8

		echo ''

		echo "${YELLOW}usr/share 目录 TOP8${RESET}"

		du -hsx ./usr/share/* 2>/dev/null | sort -rh | head -n 8

		echo ''
		echo "${YELLOW}按回车键返回。Press enter to return.${RESET}"
		read
		SpaceOccupation

	fi
	###############################
	if [ "${OPTION}" == '2' ]; then
		echo '正在加载中，可能需要几秒钟时间，加载时间取决于文件数量和闪存读写速度。'
		echo 'Loading may take several seconds, depending on the number of files and the UFS or emmc flash read and write speed.'
		echo "${YELLOW}termux 文件大小排行榜(30名)${RESET}"

		find ./ -type f -print0 2>/dev/null | xargs -0 du | sort -n | tail -30 | cut -f2 | xargs -I{} du -sh {}
		echo "${YELLOW}按回车键返回。Press enter to return.${RESET}"
		read
		SpaceOccupation

	fi

	if [ "${OPTION}" == '3' ]; then
		cd /sdcard
		echo '正在加载中，可能需要几秒钟时间，加载时间取决于文件数量和闪存读写速度。'
		echo 'Loading may take several seconds, depending on the number of files and the UFS or emmc flash read and write speed.'
		echo "${YELLOW}sdcard 目录 TOP15${RESET}"
		du -hsx ./* ./.* 2>/dev/null | sort -rh | head -n 15

		echo "${YELLOW}sdcard文件大小排行榜(30名)${RESET}"

		find ./ -type f -print0 2>/dev/null | xargs -0 du | sort -n | tail -30 | cut -f2 | xargs -I{} du -sh {}

		echo "${YELLOW}按回车键返回。Press enter to return.${RESET}"
		read
		SpaceOccupation
	fi

	if [ "${OPTION}" == '4' ]; then
		echo "${YELLOW}Disk usage${RESET}"
		df -h | grep G | grep -v tmpfs
		echo "${YELLOW}按回车键返回。Press enter to return.${RESET} "
		read
		SpaceOccupation
	fi

	#####################################
	if [ "${OPTION}" == '0' ]; then

		MainMenu
	fi

	MainMenu

}

########################################################################
UPDATEMANAGER() {
	#curl -L -o ${PREFIX}/bin/debian-i 'https://gitee.com/mo2/linux/raw/master/debian.sh'
	aria2c --allow-overwrite=true -d ${PREFIX}/bin -o debian-i 'https://gitee.com/mo2/linux/raw/master/debian.sh' || wget -O ${PREFIX}/bin/debian-i 'https://gitee.com/mo2/linux/raw/master/debian.sh'
	if [ "${LINUXDISTRO}" != "Android" ]; then
		sed -i '1 c\#!/bin/bash' ${PREFIX}/bin/debian-i
	fi

	echo "${YELLOW}更新完成，按回车键返回。${RESET}"
	echo 'Press enter to return.'
	chmod +x ${PREFIX}/bin/debian-i
	read
	#bash ${PREFIX}/bin/debian-i
	source ${PREFIX}/bin/debian-i

}
#################################
DOWNLOADVNCAPK() {
	if [ ! -e ${PREFIX}/bin/git ]; then
		apt update
		apt install -y git
	fi

	cd /sdcard/Download || mkdir -p /sdcard/Download && cd /sdcard/Download
	if (whiptail --title "您想要下载哪个软件?" --yes-button 'VNC Viewer' --no-button 'XServer XSDL' --yesno "vnc操作体验更好,当前版本已经可以通过pulse server来传输音频。xsdl对某些软件的兼容性更高，但操作体验没有vnc好。VNC has a better operating experience and is also smoother.XSDL is more compatible with some software， but the experience is not as good as VNC in every way.\n若VNC启动后仍无声音，则请前往Play商店或Fdroid更新termux至最新版本,再安装termux:api.apk" 16 50); then
		echo 'Press enter to start the download, and press Ctrl + C to cancel.'
		echo "${YELLOW}按回车键开始下载，按Ctrl+C取消。${RESET}"
		read
		echo 'Downloading vnc viewer...'
		#rm -f 'VNCViewer_com-realvnc-viewer-android-3-6-1-42089.tar.xz' 2>/dev/null
		echo '正在为您下载至/sdcard/Download目录...'
		echo 'Download size ≈11MB'
		if [ -d "/sdcard/Download/.GITCLONEVNCCLIENT" ]; then
			rm -rf /sdcard/Download/.GITCLONEVNCCLIENT
		fi

		git clone -b vnc --depth=1 https://gitee.com/mo2/VncClient.git .GITCLONEVNCCLIENT
		mv -f /sdcard/Download/.GITCLONEVNCCLIENT/vnc/vnc36142089.tar.xz ./
		#aria2c -x 16 -k 1M --split=16 --allow-overwrite=true 'https://cdn.tmoe.me/git/linux/VNCViewer_com-realvnc-viewer-android-3-6-1-42089.tar.xz' || aria2c -x 16 -k 1M --split=16 --allow-overwrite=true 'https://m.tmoe.me/down/share/Android/VNC/VNCViewer_com-realvnc-viewer-android-3-6-1-42089.tar.xz'
		echo '正在解压...'
		tar -Jxvf vnc36142089.tar.xz
		#tar -Jxvf 'VNCViewer_com-realvnc-viewer-android-3-6-1-42089.tar.xz'
		rm -rf /sdcard/Download/.GITCLONEVNCCLIENT
		rm -f /sdcard/Download/vnc36142089.tar.xz
		echo '正在删除压缩包...'
		echo 'Deleting ...'
		#rm -f 'VNCViewer_com-realvnc-viewer-android-3-6-1-42089.tar.xz'
		am start -n com.android.documentsui/com.android.documentsui.ViewDownloadsActivity
		echo "${YELLOW}解压成功，请进入下载目录手动安装。${RESET}"
		echo '文件名称 VNC Viewer_com,realvnc,viewer,android_3,6,1,42089.apk'
		cd ${cur}
	else
		echo 'Press enter to start the download, and press Ctrl + C to cancel.'
		echo '按回车键开始下载，按Ctrl+C取消。'
		read
		echo 'Downloading xsdl...'
		#rm -f 'XServerXSDL-X-org-server_1-20-41.tar.xz' 2>/dev/null
		echo '正在为您下载至/sdcard/Download目录...'
		echo 'Download size ≈29MB'
		if [ -d "/sdcard/Download/.GITCLONEVNCCLIENT" ]; then
			rm -rf /sdcard/Download/.GITCLONEVNCCLIENT
		fi

		git clone -b xsdl --depth=1 https://gitee.com/mo2/VncClient.git .GITCLONEVNCCLIENT
		mv -f /sdcard/Download/.GITCLONEVNCCLIENT/xsdl/XSERVERXSDLANDROID.tar.xz ./
		#		aria2c -x 16 -k 1M --split=16 --allow-overwrite=true 'https://cdn.tmoe.me/git/linux/XServerXSDL-X-org-server_1-20-41.tar.xz' || aria2c -x 16 -k 1M --split=16 --allow-overwrite=true 'https://m.tmoe.me/down/share/Android/VNC/XServerXSDL-X-org-server_1-20-41.tar.xz'
		echo '正在解压...'
		tar -Jxvf XSERVERXSDLANDROID.tar.xz
		#tar -Jxvf 'XServerXSDL-X-org-server_1-20-41.tar.xz'
		rm -rf /sdcard/Download/.GITCLONEVNCCLIENT
		rm -f /sdcard/Download/XSERVERXSDLANDROID.tar.xz
		echo '正在删除压缩包...'
		echo 'Deleting ...'
		#rm -f 'XServerXSDL-X-org-server_1-20-41.tar.xz'

		echo '解压成功，请进入下载目录手动安装。'
		echo '文件名称 XServer XSDL*.apk'
		am start -n com.android.documentsui/com.android.documentsui.ViewDownloadsActivity
		cd ${cur}
	fi

}
#########################################
STARTVSCODE() {
	if [ ! -e ${PREFIX}/bin/git ]; then
		apt update
		apt install -y git
	fi

	if [ ! -d "${HOME}/${DebianFolder}" ]; then
		echo "未检测到${DebianFolder},请先安装debian_arm64"
		echo "Detected that you did not install ${DebianFolder}, please install debian first."
		echo "${YELLOW}按回车键返回。${RESET}"
		echo 'Press enter to return.'
		read
		MainMenu
	fi
	if [ ! -e "${PREFIX}/bin/code" ]; then
		cat >${PREFIX}/bin/code <<-EndOfFile
			#!/data/data/com.termux/files/usr/bin/bash
			touch "${HOME}/debian_arm64/tmp/startcode.tmp"
			am start -a android.intent.action.VIEW -d "http://localhost:8080"
			echo "本机默认vscode服务地址localhost:8080"
			echo The LAN VNC address 局域网地址\$(ip -4 -br -c a | tail -n 1 | cut -d '/' -f 1 | cut -d 'P' -f 2):8080
			echo "Please paste the address into your browser!"
			echo "请将地址粘贴到浏览器的地址栏中"


			echo "您之后可以输code来启动VSCode Server."
			echo 'You can type "code" to start VScodeServer.'
			debian
		EndOfFile
		chmod +x ${PREFIX}/bin/code
	fi

	if [ ! -e "${HOME}/${DebianFolder}/etc/tmp/sed-vscode.tmp" ]; then
		mkdir -p ${HOME}/${DebianFolder}/etc/tmp/

		cat >${HOME}/${DebianFolder}/etc/tmp/sed-vscode.tmp <<-'EOF'
			if [ -e "/tmp/startcode.tmp" ]; then
				echo "正在为您启动VSCode服务(器),请复制密码，并在浏览器的密码框中粘贴。"
				echo "The VSCode service(server) is starting, please copy the password and paste it in your browser."

				rm -f /tmp/startcode.tmp
				code &
				echo "已为您启动VSCode服务!"
				echo "VScodeServer has been started,enjoy it !"
				echo "您可以输pkill code来停止服务(器)。"
				echo 'You can type "pkill code" to stop vscode service(server).'
			fi
		EOF
	fi

	if [ ! -f "${HOME}/${DebianFolder}/root/.zshrc" ]; then
		echo "" >>${HOME}/${DebianFolder}/root/.zshrc
	fi
	if [ ! -f "${HOME}/${DebianFolder}/root/.bashrc" ]; then
		echo "" >>${HOME}/${DebianFolder}/root/.bashrc
	fi

	grep '/tmp/startcode.tmp' ${HOME}/${DebianFolder}/root/.bashrc >/dev/null || sed -i "$ r ${HOME}/${DebianFolder}/etc/tmp/sed-vscode.tmp" ${HOME}/${DebianFolder}/root/.bashrc
	grep '/tmp/startcode.tmp' ${HOME}/${DebianFolder}/root/.zshrc >/dev/null || sed -i "$ r ${HOME}/${DebianFolder}/etc/tmp/sed-vscode.tmp" ${HOME}/${DebianFolder}/root/.zshrc

	if [ -e "${HOME}/${DebianFolder}/usr/bin/code" ]; then
		code
	else

		cd ${HOME}
		if [ -d ".VSCODESERVERTMPFILE" ]; then
			rm -rf .VSCODESERVERTMPFILE
		fi

		echo "server版商店中不包含所有插件，如需下载额外插件，请前往微软vscode官方在线商店下载vsix后缀的离线插件，并手动安装。 https://marketplace.visualstudio.com/vscode"
		git clone -b build --depth=1 https://gitee.com/mo2/vscode-server.git .VSCODESERVERTMPFILE
		cd .VSCODESERVERTMPFILE
		tar -Jxvf code-server-arm64.tar.xz
		chmod +x code
		mv -f code "${HOME}/${DebianFolder}/usr/bin/"
		cd ${cur}
		rm -rf ${HOME}/.VSCODESERVERTMPFILE
		echo "Congratulations, you have successfully installed vscode server!"
		echo "您已成功安装VSCode服务，如需卸载请输rm -f ${PREFIX}/bin/code  ${HOME}/${DebianFolder}/usr/bin/code"

		grep "keyCode" ${HOME}/${DebianFolder}/root/.local/share/code-server/User/settings.json >/dev/null || mkdir -p ${HOME}/${DebianFolder}/root/.local/share/code-server/User && cat >${HOME}/${DebianFolder}/root/.local/share/code-server/User/settings.json <<-'EndOfFile'
			{
			"keyboard.dispatch": "keyCode"
			}
		EndOfFile

		code
	fi

}
#####################################
DownloadVideoTutorial() {
	cd /sdcard/Download
	if [ -f "20200229vnc教程06.mp4" ]; then

		if (whiptail --title "检测到视频已下载,请选择您需要执行的操作！" --yes-button 'Play播放o(*￣▽￣*)o' --no-button '重新下载(っ °Д °)' --yesno "Detected that the video has been downloaded, do you want to play it, or download it again?" 7 60); then
			PLAYVideoTutorial
		else
			DOWNLOADVideoTutorialAGAIN
		fi
	else
		DOWNLOADVideoTutorialAGAIN

	fi

}

##########################
DOWNLOADVideoTutorialAGAIN() {
	aria2c -x 16 -k 1M --split=16 --allow-overwrite=true -o "20200229vnc教程06.mp4" 'https://cdn.tmoe.me/Tmoe-Debian-Tool/20200229VNC%E6%95%99%E7%A8%8B06.mp4' || aria2c -x 16 -k 1M --split=16 --allow-overwrite=true -o "20200229vnc教程06.mp4" 'https://m.tmoe.me/down/share/videos/20200229vnc%E6%95%99%E7%A8%8B06.mp4' || wget -O "20200229vnc教程06.mp4" 'https://cdn.tmoe.me/Tmoe-Debian-Tool/20200229VNC%E6%95%99%E7%A8%8B06.mp4'
	PLAYVideoTutorial
}
PLAYVideoTutorial() {
	termux-open "20200229vnc教程06.mp4"
	echo "${YELLOW}若视频无法自动播放，则请进入下载目录手动播放。${RESET}"
	echo "If the video does not play automatically, please enter the download directory to play it manually."
	echo "转载视频须经原作者同意，请勿擅自将视频上传至B站等平台。"
	echo "Do not upload video to platforms such as YouTube without authorization."
	echo "按回车键继续,按Ctrl+C取消。"
	echo "${YELLOW}Press enter to continue.${RESET}"
	read
	am start -n com.android.documentsui/com.android.documentsui.ViewDownloadsActivity
	cd ${cur}
}
#####################################
CHROOTINSTALLDebian() {
	echo "This feature currently only supports Linux systems and is still in beta."
	echo "本功能目前仅对Linux系统测试开放。"
	echo "This feature is currently in the beta stage. If you find that some directories cannot be unloaded forcibly before removing the debian system, please restart your device before uninstalling the chroot container to prevent the mounted directory from being deleted by mistake."
	echo "本功能目前仍处于测试阶段，移除debian系统前若发现部分已挂载目录无法强制卸载，请重启设备再卸载chroot容器，防止已挂载目录被误删！"
	echo "按回车键继续,按Ctrl+C取消。"
	echo "${YELLOW}Press enter to continue.${RESET}"
	read
	touch ~/.ChrootInstallationDetectionFile
	installDebian
}
#################################
INSTALLDEBIANORDOWNLOADRECOVERYTARXZ() {
	if [ ! -d "${DebianCHROOT}" ]; then
		less -meQ <<-'EndOfFile'
			   Tmoe-Debian-Tool（以下简称“本工具”）尊重并保护所有使用服务的用户的个人隐私权。
			本工具遵循GNU General Public License v2.0 （开源许可协议）,旨在追求开放和自由。
			由于恢复包未存储于git仓库，而存储于天萌网盘，故您必须承担并知悉其中的风险。
			强烈建议您选择更为安全的安装方式，即从软件源镜像站下载容器镜像，再自行选择安装内容。
			本工具的开发者郑重承诺：恢复包内的系统不会使用和披露您的个人信息，也不存在任何侵害您个人隐私的行为。
			本工具会不时更新本协议，您在同意本工具服务使用协议之时，即视为您已经同意本协议全部内容。本协议属于本工具服务使用协议不可分割的一部分。


			1.禁止条例
			(a)禁止将本工具安装的GNU/Linux用于违法行为，例如：网络渗透、社会工程、域名未备案私自设立商用web服务等。

			2. 适用范围
			(a)在您使用本工具时，通过天萌网盘下载的恢复包系统；
			(b)在您使用本工具时，通过清华镜像站安装的基础系统。
			您了解并同意，以下信息不适用本许可协议：
			(a)您在本工具的相关网站发布的有关信息数据，包括但不限于参与活动、点赞信息及评价详情；
			(b)违反法律规定或违反本工具规则行为及本工具已对您采取的措施。

			3. 信息使用
			(a)本工具不会收集或向任何无关第三方提供、出售、出租、分享或交易您的个人信息。
			(b)本工具亦不允许任何第三方以任何手段收集、编辑、出售或者无偿传播您的个人信息。
			                 
			4.下载说明
			(a)天萌网盘内的文件有可能由于网站被黑、文件失效、文件被替换、网站服务器出错等原因而导致下载出错或下载内容被劫持,故本工具在解压前会自动校验文件的sha256哈希值。
			(b)强烈建议您选择更为安全的安装方式，即从软件源镜像站下载容器镜像，再自行选择安装内容。

			5. 恢复包的使用
			(a)在您未拒绝接受恢复包的情况下，本工具会将恢复包下载至内置存储设备，并将其解压出来，以便您能快速安装并使用Debian GNU/Linux的图形桌面环境。本工具下载的恢复包不会为您提供个性化服务，您需要自行安装、配置第三方软件和主题美化。
			(b)您有权选择接受或拒绝使用恢复包或本工具。

			6. 信息安全
			(a)本工具安装的是原生GNU/Linux 系统，截至2020-03-12，默认没有开启安全保护和防火墙功能，请您妥善保管root密码及其它重要账号信息。
			同时希望您能注意在信息网络上不存在“绝对完善的安全措施”。

			7.最终用户许可协议的更改
			(a)如果决定更改最终用户许可协议，我们会在本协议中、本工具网站中以及我们认为适当的位置发布这些更改，以便您了解如何保障我们双方的权益。
			(b)本工具开发者保留随时修改本协议的权利，因此请经常查看。
		EndOfFile
		echo 'You must agree to EULA to use this tool.'
		echo 'Press Enter to agree, otherwise press Ctrl + C or close the terminal directly.'
		echo "${YELLOW}按回车键同意《最终用户许可协议》，否则请按Ctrl+C或直接关闭终端。${RESET} "
		read
	fi
	CHOOSEWHICHGNULINUX
}

###################################################
DOWNLOADDEBIANXFCETARXZ() {
	aria2c -x 16 -k 1M --split=16 --allow-overwrite=true -o "debian_2020-03-11_17-31.tar.xz" 'https://cdn.tmoe.me/Tmoe-Debian-Tool/proot/Debian-xfce/debian_2020-03-11_17-31.tar.xz' || aria2c -x 16 -k 1M --split=16 --allow-overwrite=true -o "debian_2020-03-11_17-31.tar.xz" 'https://m.tmoe.me/show/share/Android/proot/Debian-xfce/debian_2020-03-11_17-31.tar.xz'
	echo 'Verifying sha256sum ...'
	echo '正在校验sha256sum...'
	SHA256SUMDEBIAN="$(sha256sum 'debian_2020-03-11_17-31.tar.xz' | cut -c 1-64)"
	CORRENTSHA256SUM='931565aa44cd12a7a5ed40c12715724d6bed51eb4fccf1a91a3c6a4346d12721' #DevSkim: ignore DS173237
	if [ "${SHA256SUMDEBIAN}" != "${CORRENTSHA256SUM}" ]; then
		echo "当前文件的sha256校验值为${SHA256SUMDEBIAN}"
		echo "远程文件的sha256校验值为${CORRENTSHA256SUM}"
		echo 'sha256校验值不一致，请重新下载！'
		echo 'sha256sum value is inconsistent, please download again.'
		echo "按回车键无视错误并继续安装,按Ctrl+C取消。"
		echo "${YELLOW}Press enter to continue.${RESET}"
		read

	else
		echo 'Congratulations,检测到sha256sum一致'
		echo 'Detected that sha256sum is the same as the source code, and your download is correct.'
	fi
	UNXZDEBIANRECOVERYKIT

}
#####################################
UNXZDEBIANRECOVERYKIT() {
	echo "                                        "
	echo "                            .:7E        "
	echo "            .iv7vrrrrr7uQBBBBBBB:       "
	echo "           v17::.........:SBBBUg        "
	echo "        vKLi.........:. .  vBQrQ        "
	echo "   sqMBBBr.......... :i. .  SQIX        "
	echo "   BBQBBr.:...:....:. 1:.....v. ..      "
	echo "    UBBB..:..:i.....i YK:: ..:   i:     "
	echo "     7Bg.... iv.....r.ijL7...i. .Lu     "
	echo "  IB: rb...i iui....rir :Si..:::ibr     "
	echo "  J7.  :r.is..vrL:..i7i  7U...Z7i..     "
	echo "  ...   7..I:.: 7v.ri.755P1. .S  ::     "
	echo "    :   r:.i5KEv:.:.  :.  ::..X..::     "
	echo "   7is. :v .sr::.         :: :2. ::     "
	echo "   2:.  .u: r.     ::::   r: ij: .r  :  "
	echo "   ..   .v1 .v.    .   .7Qr: Lqi .r. i  "
	echo "   :u   .iq: :PBEPjvviII5P7::5Du: .v    "
	echo "    .i  :iUr r:v::i:::::.:.:PPrD7: ii   "
	echo "    :v. iiSrr   :..   s i.  vPrvsr. r.  "
	echo "     ...:7sv:  ..PL  .Q.:.   IY717i .7. "
	echo "      i7LUJv.   . .     .:   YI7bIr :ur "
	echo "     Y rLXJL7.:jvi:i:::rvU:.7PP XQ. 7r7 "
	echo "    ir iJgL:uRB5UPjriirqKJ2PQMP :Yi17.v "
	echo "         :   r. ..      .. .:i  ...     "
	echo "正在解压debian_2020-03-11_17-31.tar.xz，Decompressing debian-xfce recovery package, please be patient."
	pv "debian_2020-03-11_17-31.tar.xz" | tar -PpJx 2>/dev/null
	cd "$cur"
	if [ ! -L '/data/data/com.termux/files/home/storage/external-1' ]; then

		sed -i 's@^command+=" -b /data/data/com.termux/files/home/storage/external-1@#&@g' ${PREFIX}/bin/debian 2>/dev/null
		rm -f ${HOME}/debian_arm64/root/tf 2>/dev/null
	fi
	echo '解压完成，您之后可以输startvnc来启动vnc服务，输stopvnc停止'
	echo '在debian系统内输debian-i启动debian应用安装及远程桌面配置修改工具。'
	echo 'The vnc service is about to start for you. The password you entered is hidden.'
	echo '即将为您启动vnc服务，您需要输两遍（不可见的）密码。'
	echo "When prompted for a view-only password, it is recommended that you enter 'n'"
	echo '如果提示view-only,那么建议您输n,选择权在您自己的手上。'
	echo '请输入6至8位的VNC密码'
	source ${PREFIX}/bin/startvnc

}
###############################
TERMUXINSTALLXFCE() {
	if (("${ANDROIDVERSION}" < '7')); then
		echo "检测到您当前的安卓系统版本低于7，继续操作可能存在问题，是否继续？"
		echo "Since termux has officially stopped maintaining the old system below android 7, it is not recommended that you continue to operate."
		echo 'Press Enter to continue.'
		echo "${YELLOW}按回车键继续，按Ctrl+C取消。${RESET}"
		read
	fi
	OPTION=$(whiptail --title "Termux GUI" --menu "Termux native GUI has fewer software packages. It is recommended that you install a debian system. The following options only apply to termux.Termux原系统GUI可玩性较低，建议您安装debian系统，以下选项仅适用于termux。" 16 60 4 \
		"1" "install xfce4" \
		"2" "modify vnc conf" \
		"3" "remove xfce4" \
		"4" "更换为清华源" \
		"5" "下载termux_0.92_Fdroid.apk" \
		"0" "Back to the main menu 返回主菜单" \
		3>&1 1>&2 2>&3)
	###########################################################################
	if [ "${OPTION}" == '0' ]; then
		MainMenu
	fi
	#####################################
	if [ "${OPTION}" == '1' ]; then
		if [ -e "${PREFIX}/bin/xfwm4" ]; then
			echo "检测到您已安装，是否继续？"
			echo 'Press enter to continue'
			echo "${YELLOW}按回车键确认继续,按Ctrl+C取消。${RESET}"
			read
		fi
		apt update
		apt install -y x11-repo
		apt update
		apt dist-upgrade -y

		apt install -y xfce tigervnc aterm
		cat >${PREFIX}/bin/startvnc <<-'EndOfFile'
			#!/data/data/com.termux/files/usr/bin/bash
			pkill Xvnc 2>/dev/null 
			pulseaudio --start 
			echo "正在启动vnc服务,本机默认vnc地址localhost:5901"
			echo The LAN VNC address 局域网地址 $(ip -4 -br -c a | tail -n 1 | cut -d '/' -f 1 | cut -d 'P' -f 2):5901
			export DISPLAY=:1
			Xvnc -geometry 720x1440 -depth 24 --SecurityTypes=None $DISPLAY &
			export PULSE_SERVER=127.0.0.1
			am start -n com.realvnc.viewer.android/com.realvnc.viewer.android.app.ConnectionChooserActivity
			sleep 1s
			thunar &
			echo "已为您启动vnc服务 Vnc service has been started, enjoy it!"
			echo "默认为前台运行，您可以按Ctrl+C终止当前进程。"
			startxfce4

		EndOfFile
		chmod +x ${PREFIX}/bin/startvnc
		source ${PREFIX}/bin/startvnc
	fi
	#######################
	if [ "${OPTION}" == '2' ]; then
		MODIFYANDROIDTERMUXVNCCONF
	fi
	##################
	if [ "${OPTION}" == '3' ]; then
		REMOVEANDROIDTERMUXXFCE
	fi
	##################
	if [ "${OPTION}" == '4' ]; then
		TERMUXTUNASOURCESLIST
	fi
	##################
	if [ "${OPTION}" == '5' ]; then
		ARIA2CDOWNLOADTERMUXAPK
	fi

}

#####################################
ARIA2CDOWNLOADTERMUXAPK() {
	cd /sdcard/Download
	if [ -f "com.termux_Fdroid.apk" ]; then

		if (whiptail --title "检测到文件已下载,请选择您需要执行的操作！" --yes-button 'install(*￣▽￣*)o' --no-button 'Download again(っ °Д °)' --yesno "Detected that the file has been downloaded, do you want to install it, or download it again?" 7 60); then
			INSTALLTERMUXAPK
		else
			DOWNLOADTERMUXAPKAGAIN
		fi
	else
		DOWNLOADTERMUXAPKAGAIN

	fi
	echo 'press Enter to return.'
	echo "${YELLOW}按回车键返回。${RESET}"
	read
	MainMenu
}
#######################################
DOWNLOADTERMUXAPKAGAIN() {
	echo 'Press enter to start the download, and press Ctrl + C to cancel.'
	echo "${YELLOW}按回车键开始下载，按Ctrl+C取消。${RESET}"
	read
	echo 'Downloading termux apk...'
	echo '正在为您下载至/sdcard/Download目录...'
	echo '下载完成后，需要您手动安装。'
	aria2c -x 16 -k 1M --split=16 --allow-overwrite=true -o "com.termux_Fdroid.apk" 'https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo/com.termux_92.apk'
	INSTALLTERMUXAPK
}
INSTALLTERMUXAPK() {
	echo "${YELLOW}下载完成，请进入下载目录手动安装。${RESET}"
	am start -n com.android.documentsui/com.android.documentsui.ViewDownloadsActivity
	cd ${cur}
}

##################################
INSTALLWEBNOVNC() {
	if [ "${LINUXDISTRO}" = 'Android' ]; then
		if [ ! -e "${PREFIX}/bin/python" ]; then
			apt update
			apt install -y python
		fi
	elif [ "${LINUXDISTRO}" = 'debian' ]; then
		if [ ! -e "/usr/bin/python3" ]; then
			apt install -y python3
		fi
	fi

	if [ ! -e "${HOME}/.vnc/utils/launch.sh" ]; then
		mkdir -p ${HOME}/.vnc
		cd ${HOME}/.vnc
		aria2c -x 3 -k 1M --split=5 --allow-overwrite=true -o 'novnc.deb' 'https://mirrors.tuna.tsinghua.edu.cn/debian/pool/main/n/novnc/novnc_1.0.0-3_all.deb'
		dpkg-deb -X novnc.deb ./
		cp -prf ./usr/share/novnc/* ./
		cp -rf ./usr/share/doc ./
		rm -rf ./usr
	fi
	STARTWEBNOVNC
}
#######################
STARTWEBNOVNC() {
	pkill pulseaudio 2>/dev/null
	cd ${HOME}/.vnc/utils/
	if [ ! -d "websockify" ]; then
		git clone git://github.com/novnc/websockify.git --depth=1 ./websockify
	fi
	echo 'Before starting novnc, you must know the following: 1. NOVNC can connect without installing a client. 2. You can use the Bluetooth mouse to operate on the local browser, or you can use the browser of other devices to open the local novnc address.'
	echo "在启动novnc之前，您必须知悉novnc无需安装客户端，您可以使用蓝牙鼠标在本机浏览器上进行操作，亦可使用其它设备的浏览器打开本机的novnc地址。"
	echo "如需启动vnc app，而非web端，那么您下次可以输startvnc"
	echo "若无声音，则请输stopvnc并重启终端。"
	bash launch.sh --vnc localhost:5901 --listen 6080 &
	echo '正在为您启动novnc'
	echo 'Starting novnc service,please be patient.'
	if [ "${LINUXDISTRO}" = 'Android' ]; then
		am start -a android.intent.action.VIEW -d "http://localhost:6080/vnc.html"
	elif [ "${WINDOWSDISTRO}" = "WSL" ]; then
		wsl-open 'http://localhost:6080/vnc.html'
	else
		firefox 'http://localhost:6080/vnc.html'
	fi
	echo "本机默认novnc地址${YELLOW}http://localhost:6080/vnc.html${RESET}"
	echo The LAN VNC address 局域网地址$(ip -4 -br -c a | tail -n 1 | cut -d '/' -f 1 | cut -d 'P' -f 2):6080/vnc.html
	echo "注意：novnc地址和vnc地址是${YELLOW}不同${RESET}的，请在${YELLOW}浏览器${RESET}中输入novnc地址。"
	echo 'Other devices in the LAN need to enter the novnc address of the LAN. Do not forget /vnc.html after the port number'
	echo "非本机（如局域网内的pc）需要输局域网novnc地址，不要忘记端口号后的/vnc.html"
	if [ -d "${DebianCHROOT}" ]; then
		touch ~/${DebianFolder}/root/.vnc/startvnc
		${PREFIX}/bin/debian
	else
		${PREFIX}/bin/startvnc
	fi

}

#################
MODIFYANDROIDTERMUXVNCCONF() {
	if [ ! -e ${PREFIX}/bin/startvnc ]; then
		echo "${PREFIX}/bin/startvnc is not detected, maybe you have not installed the graphical desktop environment, do you want to continue editing?"
		echo '未检测到startvnc,您可能尚未安装图形桌面，是否继续编辑?'
		echo "Press Enter to confirm."
		echo "${YELLOW}按回车键确认编辑。${RESET}"
		read
	fi
	CURRENTTERMUXVNCRES=$(sed -n 7p "$(which startvnc)" | cut -d 'y' -f 2 | cut -d '-' -f 1)
	if (whiptail --title "modify vnc configuration" --yes-button '分辨率resolution' --no-button '其它other' --yesno "您想要修改哪些配置信息？What configuration do you want to modify?" 9 50); then
		if grep -q 'debian_' "$(which startvnc)"; then
			echo "您当前使用的startvnc配置为debian系统专用版，请进入debian系统后输debian-i修改"
			echo "本选项仅适用于termux原系统。"
			echo 'Press Enter to return.'
			echo "${YELLOW}按回车键返回。${RESET}"
			read
			MainMenu
		fi
		TARGET=$(whiptail --inputbox "Please enter a resolution,请输入分辨率,例如2880x1440,2400x1200,1920x1080,1920x960,1440x720,1280x1024,1280x960,1280x720,1024x768,800x680等等,默认为720x1440,当前为${CURRENTTERMUXVNCRES}。分辨率可自定义，但建议您根据屏幕比例来调整，输入完成后按回车键确认，修改完成后将自动停止VNC服务。注意：x为英文小写，不是乘号。Press Enter after the input is completed." 16 50 --title "请在方框内输入 水平像素x垂直像素 (数字x数字) " 3>&1 1>&2 2>&3)
		#此处termux的whiptail跟debian不同，必须截取Error前的字符。
		TRUETARGET="$(echo ${TARGET} | cut -d 'E' -f 1)"
		#下面那条变量TRUETARGETTARGET前加空格
		#sed -i "s#${CURRENTTERMUXVNCRES}# ${TRUETARGETTARGET}#" "$(which startvnc)"
		sed -i "7 c Xvnc -geometry ${TRUETARGET} -depth 24 --SecurityTypes=None \$DISPLAY \&" "$(which startvnc)"
		echo 'Your current resolution has been modified.'
		echo '您当前的分辨率已经修改为'
		echo $(sed -n 7p "$(which startvnc)" | cut -d 'y' -f 2 | cut -d '-' -f 1)
	else
		echo '您可以手动修改vnc的配置信息'
		echo 'If you want to modify the resolution, please change the 720x1440 (default resolution , vertical screen) to another resolution, such as 1920x1080 (landscape).'
		echo '若您想要修改分辨率，请将默认的720x1440（竖屏）改为其它您想要的分辨率，例如1920x1080（横屏）。'
		echo "您当前分辨率为${CURRENTTERMUXVNCRES}"
		echo '改完后按Ctrl+S保存，Ctrl+X退出。'
		echo "Press Enter to confirm."
		echo "${YELLOW}按回车键确认编辑。${RESET}"
		read
		nano ${PREFIX}/bin/startvnc || nano $(which startvnc)
		echo "您当前分辨率为$(sed -n 7p "$(which startvnc)" | cut -d 'y' -f 2 | cut -d '-' -f 1)"
	fi
	echo 'Press Enter to return.'
	echo "${YELLOW}按回车键返回。${RESET}"
	read
	MainMenu

}
###############
REMOVEANDROIDTERMUXXFCE() {
	echo "${YELLOW}按回车键确认卸载,按Ctfl+C取消${RESET} "
	echo 'Press enter to confirm ,press Ctfl + C to cancel'
	read
	apt purge -y ^xfce tigervnc aterm
	apt purge -y x11-repo
	apt autoremove
	echo 'Press Enter to return.'
	echo "${YELLOW}按回车键返回。${RESET}"
	read
	MainMenu

}
#################
TERMUXTUNASOURCESLIST() {
	if ! grep -q '^deb.*edu.cn.*termux-packages-24' '/data/data/com.termux/files/usr/etc/apt/sources.list'; then
		sed -i 's@^\(deb.*stable main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/termux-packages-24 stable main@' /data/data/com.termux/files/usr/etc/apt/sources.list
		if ! grep -q '^deb' '/data/data/com.termux/files/usr/etc/apt/sources.list'; then
			echo -e '\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/termux-packages-24 stable main' >>/data/data/com.termux/files/usr/etc/apt/sources.list
		fi
	fi

	if ! grep -q '^deb.*tuna' '/data/data/com.termux/files/usr/etc/apt/sources.list.d/game.list'; then
		sed -i 's@^\(deb.*games stable\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/game-packages-24 games stable@' /data/data/com.termux/files/usr/etc/apt/sources.list.d/game.list
	fi

	if ! grep -q '^deb.*tuna' '/data/data/com.termux/files/usr/etc/apt/sources.list.d/science.list'; then
		sed -i 's@^\(deb.*science stable\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/science-packages-24 science stable@' /data/data/com.termux/files/usr/etc/apt/sources.list.d/science.list
	fi

	if [ -e "/data/data/com.termux/files/usr/etc/apt/sources.list.d/x11.list" ]; then
		if ! grep -q '^deb.*tuna' '/data/data/com.termux/files/usr/etc/apt/sources.list.d/x11.list'; then
			sed -i 's@^\(deb.*x11 main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/x11-packages x11 main@' /data/data/com.termux/files/usr/etc/apt/sources.list.d/x11.list
		fi
	fi

	if [ -e "/data/data/com.termux/files/usr/etc/apt/sources.list.d/unstable.list" ]; then
		if ! grep -q '^deb.*tuna' '/data/data/com.termux/files/usr/etc/apt/sources.list.d/unstable.list'; then
			sed -i 's@^\(deb.*unstable main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/unstable-packages unstable main@' /data/data/com.termux/files/usr/etc/apt/sources.list.d/unstable.list
		fi
	fi

	if [ -e "/data/data/com.termux/files/usr/etc/apt/sources.list.d/root.list" ]; then
		if ! grep -q '^deb.*tuna' '/data/data/com.termux/files/usr/etc/apt/sources.list.d/root.list'; then
			sed -i 's@^\(deb.*root stable\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/termux-root-packages-24 root stable@' /data/data/com.termux/files/usr/etc/apt/sources.list.d/root.list
		fi
	fi
	apt update
	apt dist-upgrade -y
	echo '修改完成，您当前的软件源列表如下所示。'
	cat /data/data/com.termux/files/usr/etc/apt/sources.list
	cat /data/data/com.termux/files/usr/etc/apt/sources.list.d/*
	echo "您可以输${YELLOW}apt edit-sources${RESET}来手动编辑main源"
	echo "您也可以输${YELLOW}cd ${PREFIX}/etc/apt/sources.list.d ; nano ./* ${RESET}来手动编辑其它源"
	echo 'Press Enter to return.'
	echo "${YELLOW}按回车键返回。${RESET}"
	read
	ANDROIDTERMUX
	#此处要返回依赖检测处！

}
##################
CHOOSEWHICHGNULINUX() {
	SELECTGNULINUX=$(whiptail --title "GNU/Linux distros" --menu "Which distribution do you want to install? 您想要安装哪个GNU/Linux发行版?" 15 50 6 \
		"1" "Debian:最早的发行版之一" \
		"2" "Ubuntu 20.04:我的存在是因為大家的存在" \
		"3" "Kali Rolling:设计用于数字取证和渗透测试" \
		"4" "Funtoo:专注于改进Gentoo" \
		"5" "Void:基于xbps包管理器的独立发行版" \
		"0" "Back to the main menu 返回主菜单" \
		3>&1 1>&2 2>&3)

	##############################
	if [ "${SELECTGNULINUX}" == '0' ]; then
		MainMenu
	fi
	#########################
	if [ "${SELECTGNULINUX}" == '1' ]; then

		INSTALLDEBIANGNULINUXDISTRO
	fi
	##############################
	if [ "${SELECTGNULINUX}" == '2' ]; then
		INSTALLUBUNTUDISTRO2004
	fi
	##############################
	if [ "${SELECTGNULINUX}" == '3' ]; then
		INSTALLKALIROLLING
	fi
	##############################
	if [ "${SELECTGNULINUX}" == '4' ]; then
		INSTALLFuntooDISTRO
	fi
	#############################
	if [ "${SELECTGNULINUX}" == '5' ]; then
		INSTALLVOIDLINUXDISTRO
	fi
	##############################
	echo 'Press Enter to return.'
	echo "${YELLOW}按回车键返回。${RESET}"
	read
	MainMenu
}

##############################
INSTALLDEBIANGNULINUXDISTRO() {
	if (whiptail --title "Install GNU/Linux" --yes-button 'Software source' --no-button 'Download Rec pkg' --yesno "Do you want to install via Tsinghua University open source mirror station, or download the recovery package (debian-xfce.tar.xz) to install?The latter only supports arm64.您想要通过软件源镜像站来安装，还是在线下载恢复包来安装？软件源获取的是最新版镜像，且支持arm64,armhf,x86,x64等架构，安装基础系统速度很快，但安装gui速度较慢。恢复包非最新版,仅支持aarch(arm64)架构,但安装gui速度较快，且更加方便。若您无使用GUI的需求，建议选择前者。" 15 50); then
		BUSTERORSID
	else
		if [ ! -d "/sdcard/Download/backup" ]; then
			mkdir -p /sdcard/Download/backup
		fi
		cd /sdcard/Download/backup
		if [ -e "debian_2020-03-11_17-31.tar.xz" ]; then
			if (whiptail --title "Install Debian" --yes-button '解压uncompress' --no-button 'Download again' --yesno "It was detected that the recovery package has been downloaded. Do you want to uncompress it, or download it again?检测到恢复包已经下载,您想要重新直接解压还是重新下载？" 14 50); then
				UNXZDEBIANRECOVERYKIT
			else
				DOWNLOADDEBIANXFCETARXZ

			fi
		else
			DOWNLOADDEBIANXFCETARXZ

		fi
	fi
}

########################
BUSTERORSID() {
	if (whiptail --title "Debian version" --yes-button 'Sid' --no-button 'Buster' --yesno "请选择您需要安装的debian版本，Please select the debian version you need to install.Buster为当前的stable版,sid为unstable。Buster更加稳定且bug较少,但buster的软件包较旧,而sid较新。Buster is more stable and has fewer bugs, but the packages inside the buster software source are older. The sid package is relatively new." 15 50); then
		if [ "${LINUXDISTRO}" != 'iSH' ]; then
			bash -c "$(curl -fLsS 'https://gitee.com/mo2/linux/raw/master/installDebian.sh')"
		else
			wget -qO- 'https://gitee.com/mo2/linux/raw/master/installDebian.sh' | bash
		fi
	else
		bash -c "$(curl -LfsS gitee.com/mo2/linux/raw/master/installDebian.sh | sed 's:/sid:/buster:g' | sed 's:extract z:extract:' | sed 's:-sid:-buster:g' | sed 's@#deb http@deb http@g' | sed 's/.*sid main/#&/')"
	fi
}
#############
INSTALLUBUNTUDISTRO2004() {
	if [ "${archtype}" = 'amd64' ] || [ "${archtype}" = 'i386' ]; then
		bash -c "$(curl -LfsS gitee.com/mo2/linux/raw/master/installDebian.sh |
			sed 's/debian系统/ubuntu系统/g' |
			sed 's/debian system/ubuntu system/g' |
			sed 's:debian-sid:ubuntu-focal:g' |
			sed 's:debian/sid:ubuntu/focal:g' |
			sed 's:/ubuntu-ports:/ubuntu:g' |
			sed 's:Debian GNU/Linux:Ubuntu GNU/Linux:g')"
	else
		#ubuntu-ports
		bash -c "$(curl -LfsS gitee.com/mo2/linux/raw/master/installDebian.sh |
			sed 's/debian系统/ubuntu系统/g' |
			sed 's/debian system/ubuntu system/g' |
			sed 's:debian-sid:ubuntu-focal:g' |
			sed 's:debian/sid:ubuntu/focal:g' |
			sed 's:Debian GNU/Linux:Ubuntu GNU/Linux:g')"
	fi
}
##########
INSTALLKALIROLLING() {
	bash -c "$(curl -LfsS gitee.com/mo2/linux/raw/master/installDebian.sh |
		sed 's/sid main/kali-rolling main/' |
		sed 's/stable/kali-last-snapshot/g' |
		sed '/buster-backports/d' |
		sed 's:cn/debian:cn/kali:g' |
		sed 's:debian-sid:kali-rolling:g' |
		sed 's:debian/sid:kali/current:g' |
		sed 's/debian系统/kali系统/g' |
		sed 's/debian system/kali system/g' |
		sed 's/debian容器/kali容器/g' |
		sed 's:Debian GNU/Linux:Kali GNU/Linux:g')"
}
################
INSTALLFuntooDISTRO() {
	bash -c "$(curl -LfsS gitee.com/mo2/linux/raw/master/installDebian.sh |
		sed 's:debian-sid:funtoo-1.3:g' |
		sed 's:debian/sid:funtoo/1.3:g' |
		sed 's/debian系统/funtoo系统/g' |
		sed 's/debian system/funtoo system/g' |
		sed 's/debian容器/funtoo容器/g' |
		sed 's:Debian GNU/Linux:Funtoo GNU/Linux:g')"
}
#######################
INSTALLVOIDLINUXDISTRO() {
	bash -c "$(curl -LfsS gitee.com/mo2/linux/raw/master/installDebian.sh |
		sed 's:debian-sid:voidlinux-default:g' |
		sed 's:debian/sid:voidlinux/current:g' |
		sed 's/debian系统/void系统/g' |
		sed 's/debian system/void system/g' |
		sed 's/debian容器/void容器/g' |
		sed 's:Debian GNU/Linux:Void GNU/Linux:g')"
}

####################
CheckArch
##取消注释，测试用。
##MainMenu
