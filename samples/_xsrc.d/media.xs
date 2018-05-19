fn b {
	.d 'Stop playing track'
	.c 'media'
	.r 'equalizer m mpc n ncmpcpp played s'
	mpc -q pause
	m
}
fn bluetoothctl {
	.d 'Bluetooth control'
	.c 'media'
	%with-terminal /usr/bin/bluetoothctl
}
fn equalizer {|*|
	.d 'Pulse Audio equalizer'
	.a '[enable|disable|toggle|status|curve|presets|load PRESET#|adjust]'
	.c 'media'
	.r 'b m mpc n ncmpcpp played s'
	%only-X
	let (fn-filter = {grep '^Equalizer status:'|grep -o '\[.*\]' \
				|tr -d '[]'}; \
	cf = ~/.config/pulse/equalizerrc; \
	pd = ~/.config/pulse/presets) {
		if {~ $* <={%prefixes enable}} {
			pulseaudio-equalizer enable | filter
		} else if {~ $* <={%prefixes disable}} {
			pulseaudio-equalizer disable | filter
		} else if {~ $* <={%prefixes toggle}} {
			pulseaudio-equalizer toggle | filter
		} else if {~ $* <={%prefixes status}} {
			pulseaudio-equalizer status | filter
		} else if {~ $* <={%prefixes curve}} {
			let (bands; gains) {
				bands = `{tail -n+11 $cf|tail -n+16}
				gains = `{tail -n+11 $cf|head -15}
				tail -n+5 $cf|head -1
				for g $gains; b $bands {
					printf '%+4.1f dB @ %''6d Hz'\n $g $b
				}
			}
		} else if {~ $* <={%prefixes presets}} {
			ls $pd^/*.preset|xargs -d\n -n1 basename \
				|sed 's/.preset//'|nl
		} else if {~ $*(1) <={%prefixes load}} {
			let (pfl = `` \n {ls $pd^/*.preset}) {
				ed -s $pfl($*(2)) <<EOF
5a
0
0
-10
10
.
w $cf
q
EOF
			}
		} else if {~ $* <={%prefixes adjust}} {
			let (bands; b; h; gains; tf; pf) {
			let (fn-u = {|v| let (g) {
				g = $gains(`($b+1))
				switch $v (
				+ {g = `{echo $g|sed 's/-//'}}
				- {g = `{echo $g|sed 's/^.\../-&/'}}
				{if {~ $h 1} {
					g = `{echo $g|sed 's/\(-\?\).\(\..\)/' \
							^'\1'^$v^'\2/'}
				} else {
					g = `{echo $g|sed 's/\(-\?.\.\)./' \
							^'\1'^$v^'/'}
				}}
				)
				gains = $gains(1 ... $b) $g $gains(`($b+2) ...)
				printf $v
			}}; fn-rep = {|*|
				tput civis
				tput cup `($bands+1) 0
				tput ed
				printf %s <={%argify $*}
				tput cup $b $h
				tput cnorm
			}; fn-load = {
				clear
				equalizer curve
				gains = gains `{tail -n+11 $cf|head -15}
				bands = 15
				b = 1
				h = 1
				tput cup $b $h
			}; fn-update = {
				tf = `mktemp
				head -10 $cf > $tf
				for g $gains(2 ...) {echo $g >> $tf}
				tail -n+26 $cf >> $tf
				mv $tf $cf
				equalizer disable >/dev/null
				equalizer enable >/dev/null
			}; fn-save = {
				pf = $pd/^`` \n {tail -n+5 $cf|head -1}^'.preset'
				ed -s $cf <<EOF
6,9d
w $pf
q
EOF
			}; fn-revert = {
				pf = $pd/^`` \n {tail -n+5 $cf|head -1}^'.preset'
				ed -s $pf <<EOF
5a
0
0
-10
10
.
w $cf
q
EOF
				equalizer disable >/dev/null
				equalizer enable >/dev/null
				clear
				equalizer curve
				gains = gains `{tail -n+11 $cf|head -15}
			}; fn-new = {
				tput cup `($bands+1) 0
				tput ed
				printf 'new preset name: '
				pf = $pd/^<=read^'.preset'
				ed -s $cf <<EOF
6,9d
w $pf
q
EOF
			}; fn-getc = {
				%without-echo {result <=%read-char}
			}; fn-redraw = {
				clear
				equalizer curve
			}) {
			load
			rep '? for help'
			escape {|fn-break| while true {
				switch <=getc (
				h {h = 1; rep}
				j {{$b :lt $bands && b = `($b+1)}; rep}
				k {{$b :gt 1 && b = `($b-1)}; rep}
				l {h = 3; rep}
				0 {u 0; rep}
				1 {u 1; rep}
				2 {u 2; rep}
				3 {u 3; rep}
				4 {u 4; rep}
				5 {u 5; rep}
				6 {u 6; rep}
				7 {u 7; rep}
				8 {u 8; rep}
				9 {u 9; rep}
				+ {tput cup $b 0; u +; rep}
				- {tput cup $b 0; u -; rep}
				q {tput cup `($bands+1) 0; break}
				s {save; rep saved as $pf}
				n {new; rep saved as $pf}
				r {revert; rep reverted to $pf}
				u {update; rep updated active}
				t {rep `{equalizer toggle}}
				v {redraw}
				z {load; rep cancelled edits}
				\? {rep 'hjkl: move; 01234567899+-: set; ' \
					^'u: update active; z: cancel edits'\n \
					^'r: revert from preset; ' \
					^'s: save to preset; ' \
					^'n: save as new preset'\n \
					^'t: toggle active; v: redraw; q: quit'
				}
				{rep '? for help'}
				)
				printf `{tput cup $b $h}
			}}}}
		} else {
			.usage equalizer
		}
	}
}
fn gallery {|*|
	.d 'Random slideshow'
	.a 'PATH [DELAY]'
	.c 'media'
	if {~ $#* 0} {
		.usage gallery
	} else {let (dir = $(1); time = $(2)) {
		~ $time () && time = 5
		if {~ $TERM linux} {
			fbi -l <{find -L $dir -type f|shuf} \
				-t $time --autodown \
				--noverbose --blend 500 >[2]/dev/null
		} else if {~ $DISPLAY () && ~ `consoletype pty} {
			mpv --image-display-duration $time --really-quiet \
				--playlist <{find -L $dir -type f \
				|grep -e .jpg\$ -e .png\$|shuf|awk \
				'/^[^/]/ {print "'`pwd'/"$0} /^\// {print}'} \
				>[2]/dev/null

		} else {
			find -L $dir -type f|shuf|sxiv -qifb -sf -S$time \
				>[2]/dev/null
		}
	}}
}
fn grayview {|*|
	.d 'View image in grayscale'
	.a 'FILE ...'
	let (tf; _; ext) {
		for f $* {
			unwind-protect {
				(_ ext) = <={~~ $f *.*}
				tf = `mktemp^.$ext
				convert $f -type grayscale $tf
				image $tf
			} {
				rm -f $tf
			}
		}
	}
}
fn image {|*|
	.d 'Display image'
	.a 'FILE ...'
	.c 'media'
	if {~ $#* 0} {
		.usage image
	} else if {~ $TERM linux} {
		fbi --noverbose $*
	} else if {~ $DISPLAY () && ~ `consoletype pty} {
		mpv --image-display-duration inf --really-quiet $*
	} else {
		let (embed) {
			{!~ $XEMBED ()} && embed = -e $XEMBED
			sxiv -qfb $embed $* &
		}
	}
}
fn m {|*|
	.d 'Show currently playing track'
	.a '[-w]'
	.c 'media'
	.r 'b equalizer mpc n ncmpcpp played s'
	if {~ $* -w} {
		%with-quit {
			watch -x -p -t -n1 -c xs -c 'm >[2]/dev/null|head -1'}}
	%with-tempfile mi {
		mpc > $mi
		if {!grep -o '^ERROR: .*$' $mi} {
			~ `{cat $mi|wc -l} 3 && \
			printf '%s|  '^<=.%as^'%s'^<=.%an^'  |%s %s'\n \
				`` \n {cat $mi|head -1|cut -d\| -f1} \
				`` \n {cat $mi|head -1|cut -d\| -f2|cut -c3-} \
				`` \n {cat $mi|tail -n+2|head -1|xargs echo \
					|cut -d' ' -f3-} \
				`{grep -Eo '\[(playing|paused)\]' $mi}
			printf %s%s%s\n <=.%ad <={%flatten '; ' \
				`{cat $mi|tail -1|sed 's/: /:/g'}} <=.%an
		}
	}
}
fn midi {|*|
	.d 'Play MIDI files'
	.a 'FILE ...'
	.c 'media'
	if {~ $#* 0} {
		.usage midi
	} else {let (s; p) { unwind-protect {
			fluidsynth -a pulseaudio -m alsa_seq -s -i -l \
				/usr/share/soundfonts/FluidR3_*.sf2 \
				>/dev/null >[2=1] &
			s = $apid
			sleep 1
			p = `{aplaymidi -l|grep FLUID|cut -d' ' -f1}
			for f $* {aplaymidi -p $p $f}
		} {
			kill $s
		}
	}}
}
fn mpc {|*|
	.d 'Music player'
	.c 'media'
	.r 'b equalizer m n ncmpcpp played s'
	/usr/bin/mpc -f '%artist% - %album% - %track%#|  %title%' $*
}
fn mpv {|*|
	.d 'Movie player'
	.a '[mpv_OPTIONS] FILE ...'
	.c 'media'
	if {~ $#* 0} {
		.usage mpv
	} else {let (embed; video_driver) {
		if {~ $DISPLAY ()} {
			video_driver = drm
		} else {
			embed = --wid=$XEMBED
			video_driver = opengl-hq
		}
		/usr/bin/mpv --profile $video_driver $embed \
			--volume=50 --no-stop-screensaver $*
	}}
}
fn mpvl {|*|
	.d 'Movie player w/ volume leveler'
	.a '[mpv_OPTIONS] FILE ...'
	.c 'media'
	if {~ $#* 0} {
		.usage mpvl
	} else {let (afconf = 'lavfi=[highpass=f=100,dynaudnorm=f=100:r=0.7:c=1' \
		^':m=20.0:b=1]') {
		mpv --af=$afconf $*
	}}
}
fn n {
	.d 'Play next track'
	.c 'media'
	.r 'b equalizer mpc n ncmpcpp played s'
	if {~ `mpc \[playing\]} {mpc -q next} else {mpc -q play}
	m
}
fn ncmpcpp {
	.d 'MPD client'
	.a '[ncmpcpp_OPTIONS]'
	.c 'media'
	.r 'b equalizer mpc n played s'
	%with-terminal %preserving-title %with-application-keypad \
		/usr/local/bin/ncmpcpp
}
fn noise {|*|
	.d 'Audio noise generator'
	.a '[white|pink|brown [LEVEL_DB]]'
	.c 'media'
	let (pc = $*(1); pl = $*(2); color = pink; pad = -6; level = -20; \
		volume) {
		~ $pc brown && {color = brown; pad = 0}
		~ $pc pink && {color = pink; pad = -6}
		~ $pc white && {color = white; pad = -12}
		if {~ $pl -* || ~ $pl 0} {level = $pl} else {level = -20}
		volume = `($level + $pad)
		unwind-protect {
			play </dev/zero -q -t s32 -r 22050 -c 2 - \
				synth $color^noise tremolo 0.05 30 \
				vol $volume dB
		} {
			printf \n
		}
	}
}
fn p {
	.d 'Pulse Audio mixer'
	.c 'media'
	%with-terminal %preserving-title pamixer
}
fn played {|*|
	.d 'List recently-played tracks'
	.a '[-w]'
	.a '[playing]  # include current track'
	.c 'media'
	.r 'b equalizer m mpc n ncmpcpp s'
	if {~ $*(1) -w} {
		%with-quit {
			watch -t -n5 xs -c \
				'"played '^<={%argify $*(2 ...)}^'"'}}
	cat ~/.mpd/mpd.log|cut -c24-|grep '^played'|tail -n 15|tac|nl|tac
	~ $* <={%prefixes playing} && {
		printf '%14s "%s"'\n \
			`{mpc|head -2|tail -1|grep -o '\[[^]]\+\]'|tr -d []} \
			<={%argify `{mpc -f %file%|head -1}}
	}
}
fn s {|*|
	.d 'Seek within current track'
	.a '+[MM:]SS  # forward relative'
	.a '-[MM:]SS  # backward relative'
	.a '[MM:]SS  # absolute time'
	.a 'N%  # absolute percent'
	.c 'media'
	.r 'b equalizer m mpc n ncmpcpp played'
	if {~ $#* 0} {
		.usage s
	} else {
		mpc seek $*
	}
}
fn vidshuffle {|*|
	.d 'Shuffle videos under directory'
	.a 'DIRECTORY'
	.c 'media'
	if {~ $#* 0} {
		.usage vidshuffle
	} else {let (dir = $(1); filt = $(2); scale) {
		~ $filt () && filt = '*'
		~ `consoletype vt && scale = --vf scale=`{fbset \
			|grep -o '[0-9]\+[0-9]\+'|tr x :}
		mpvl --really-quiet $scale --fs --playlist <{find -L $dir \
			-type f -iname $filt|shuf \
			|awk '/^[^/]/ {print "'`pwd'/"$0} /^\// {print}'}
	}}
}
fn vol {
	.d 'Show volume of default PulseAudio output'
	.c 'media'
	if {~ `{pamixer --get-mute} 1} {printf Volume:\ muted\n} \
	else {printf Volume:\ %d%%\n `{pamixer --get-volume|cut -d\  -f1}}
}
