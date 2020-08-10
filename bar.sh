#!/bin/ksh

# lemonbar(1) bar script
# requires `ifstat` and `xdotool` packages.

red="#ff6c60"
green="#a8ff60"
yellow="#ffffb6"
blue="#b6dcfe"
magenta="#ff73fd"
cyan="#c6c5fe"
dim="#7fffffff"
icon_color=$blue

# Siji icons
timedate_icon="\xee\x80\x97"
cpu_icon="\xee\x80\xa6"    # cpu info
ram_icon="\xee\x80\xa0"    # ram usage
wl_icon="\xee\x83\xb0"     # wireless connected
wld_icon="\xee\x83\xb0"    # wireless disconnected
nxu_icon="\xee\x84\xab"    # netspeed up
nxd_icon="\xee\x84\xac"    # netspeed down
vol_icon="\xee\x81\x93"    # volume unmuted
volm_icon="\xee\x81\x92"   # volume muted
batf_icon="\xee\x80\xb7"   # battery full
batm_icon="\xee\x80\xb6"   # battery medium
batl_icon="\xee\x80\xb5"   # battery low
batc_icon="\xee\x81\x82"   # battery charging

battery=0
netinterface="trunk0"
wireless=1
wlinterface="urtwn0"

mod_datetime() {
	printf "%%{F$icon_color}$timedate_icon%%{F-} "
	date "+%F %T" | tr '\n' ' '
}

mod_desktop() {
	desktop=$(xdotool get_desktop)
	for i in $(jot 9 1)
	do
		if [ "$i" == "$desktop" ]
		then
			printf "%%{T2}%%{A:xdotool set_desktop %s:}%%{+o}%%{U$icon_color} %s %%{U-}%%{-o}%%{A}%%{T-}" $i $i
		else
			printf "%%{A:xdotool set_desktop %s:} %%{F$dim}%s%%{F-} %%{A}" $i $i
		fi
	done
}

mod_battery() {
	state=$(apm -b)
	percent=$(apm -m)
	case $state in
		0)
			printf "%%{F$green}$batf_icon%%{F-} "
			;;
		1)
			printf "%%{F$yellow}$batm_icon%%{F-} "
			;;
		2)
			printf "%%{F$red}$batl_icon%%{F-} "
			;;
		3)
			printf "%%{F$blue}$batc_icon%%{F-} "
			;;
		4)
			printf "no battery"
			return
			;;
		255)
			;;
	esac

	echo -n "$percent%"
}

mod_nxspeed() {
	set -A load $(ifstat -n -i $netinterface -b 0.1 1 | sed '1,2d')
	printf "%%{F$icon_color}$nxu_icon%%{F-}%s%%{F$dim}kb/s%%{F-}%%{F$icon_color}$nxd_icon%%{F-}%s%%{F$dim}kb/s%%{F-}" ${load[0]} ${load[1]}
}

mod_ram() {
	local mem_full=$(($(sysctl -n hw.physmem) / 1024 / 1024))
	while read -r _ _ line _; do
		mem_used=${line%%M}
	done <<-EOF
$(vmstat)
EOF
	printf "%%{F$icon_color}$ram_icon%%{F-} %s%%{F$dim}mb%%{F-}" $mem_used
}

mod_volume() {
	local mute=$(sndioctl output.mute | awk -F '=' '{print $2}')
	local level=$(sndioctl output.level | awk -F '=' '{print $2}')
	local lp=$(dc -e "$level 100 * 1/ p")
	
	if [ "$mute" = "0" ]
	then
		echo -n "%{A:sndioctl output.mute=1:}"
		echo -n "%{A4:sndioctl output.level=+0.05:}"
		echo -n "%{A5:sndioctl output.level=-0.05:}"
		printf "%%{F$icon_color}$vol_icon%%{F-} %s%%%%" $lp
		echo -n "%{A}%{A}%{A}"
	else
		echo -n "%{A:sndioctl output.mute=0:}"
		printf "%%{F$red}$volm_icon%%{F-} muted"
		echo -n "%{A}"
	fi
}

mod_cpu() {
	set -A cpu_names $(iostat -C | sed -n '2,2p')
	set -A cpu_values $(iostat -C | sed -n '3,3p')
	cpu_load=$((100 - ${cpu_values[5]}))
	cpu_temp=$(sysctl hw.sensors.cpu0.temp0 | awk -F "=" '{ gsub(" deg", "°", $2); print $2 }')
	cpu_speed=$(apm | sed '1,2d;s/.*(//;s/)//')
	printf "%%{F$icon_color}$cpu_icon%%{F-} %s%%%%%%{F$dim}/%%{F-}%s%%{F$dim}/%%{F-}%s" "$cpu_load" "$cpu_temp" "$cpu_speed"
}

mod_wireless() {
	local status=$(ifconfig $wlinterface | awk '/status:/ {print $2}')
	local id=$(ifconfig $wlinterface | awk '/(nwid|join)/ {print $3}')
	local active=$(ifconfig $netinterface | awk '/('$wlinterface').*(master)/')

	if [ "$active" != "" ]; then
		if [ "$status" == "active" ]; then
			printf "%%{F$icon_color}$wl_icon%%{F-} %s" $id
		else
			printf "%%{F$red}$wld_icon%%{F-} %%{F$dim}disconnected%%{F-}"
		fi
	else
		printf "%%{F$icon_color}$wl_icon%%{F-} %%{F$dim}ethernet%%{F-}"
	fi
}

sep() {
	printf "  "
}

while true
do
	printf "%%{l}"
	mod_desktop
	
	printf "%%{c}"
	mod_datetime

	printf "%%{r}"
	
	mod_cpu; sep
	mod_ram; sep
	
	if [ "$wireless" != "0" ]; then
		mod_wireless; sep
	fi
	
	mod_nxspeed; sep
	mod_volume
	
	if [ "$battery" != "0" ]; then
		sep; mod_battery
	fi

	echo
	sleep 0.25
done
