#!/bin/bash
# build a snapshot zip 
name=`basename "$0"`

function error_exit {
	echo "$name error: $1" >&2
	exit 1
}

function warn {
	echo "$name warning: $1" >&2
}

function usage {
	[ "$1" ] && warn "$1"
	cat >&2 <<EOF
make a binary snapshot
usage:
  $name [options]
options:
  -debug: build debug and don't strip
  -nogui: build only cli exe on Linux
  -libs=<listname>: add library files from listname to zip, "none" disables
  -libroot=<dir>: root directory for libs

EOF
	exit 1
}

arg="$1"
gui="1"
debug=""
libsfile=""
liblist=""
stagedir=""
libroot="./extlibs/built/"
distutildir="$(dirname "$(readlink -f "$0")")"
while [ ! -z "$arg" ] ; do
	case $arg in
	-debug)
		debug=1
	;;
	-nogui)
		gui=""
	;;
	-libs=*)
		libsfile="${arg#-libs=}"
	;;
	-libroot=*)
		libroot="${arg#-libroot=}"
	;;
	*)
		usage "unknown option $arg"
	;;
	esac
	shift
	arg="$1"
done

OSTYPE=`uname -o`
ARCH=`uname -m`
if [ "$OSTYPE" = "Msys" ] ; then
	OS="win"
	EXE=".exe"
	# hack for correct suffix when cross compiling
	# should be done for all platforms, but do not support cross on others yet
	if [ ! -z "$MSYSTEM_CARCH" ] ; then
		ARCH="$MSYSTEM_CARCH"
	fi
	# GUI is assumed to be included in default build on windows
	gui=""
else 
	OS=`uname -s`
	EXE=""
fi
OSARCH="$OS-$ARCH"

if [ -z "$libsfile" ] ; then
	if [ "$OS" = "Linux" -a ! -z "$gui" ] ; then
		libsfile="linux-lua52"
	else
		libsfile="none"
	fi
fi

if [ "$libsfile" != "none" ] ; then
	libsfile="${distutildir}/liblist-${libsfile}.txt"
	if [ ! -f "$libsfile" ] ; then
		error_exit "missing $libsfile"
	fi
	if [ ! -d "$libroot" ] ; then
		error_exit "missing $libroot"
	fi
	liblist=`cat "$libsfile"`
fi

REV=`svnversion  . | sed -e 's/:/-/'`
if [ -z "$debug" ] ; then
	ZIPNAME="chdkptp-r$REV-$OSARCH.zip"
else
	ZIPNAME="chdkptp-r$REV-$OSARCH-dbg.zip"
fi
stagedir="chdkptp-r$REV"

echo $ZIPNAME
if [ -f "$ZIPNAME" ] ; then
	rm -f "$ZIPNAME"
fi

PROGS=chdkptp$EXE
if [ "$OS" = "win" ] ; then
	make DEBUG="$debug" clean all || error_exit "build failed"
else
	make DEBUG="$debug" GUI= clean all || error_exit "build failed"
	if [ ! -z "$gui" ] ; then
		make DEBUG="$debug" GUI=1 GUI_SFX=_gui clean all || error_exit "GUI build failed"
		PROGS="$PROGS chdkptp_gui$EXE"
	fi
fi

if [ -f signal.so ] ; then
	PROGS="$PROGS signal.so"
fi

if [ -z "$debug" ] ; then
	strip $PROGS
fi

if [ -d "$stagedir" ] ; then
	rm -rf "$stagedir"
fi
mkdir -p "$stagedir"
mkdir -p "$stagedir"/lua/extras

cp $PROGS \
	README.TXT USAGE.TXT COPYING THANKS.TXT \
	README-LINUX-BINARIES.TXT README-OSX.TXT \
	"$stagedir"

cp lua/*.lua "$stagedir"/lua
cp lua/extras/*.lua "$stagedir"/lua/extras

if [ "$OS" != "win" ] ; then
	cp "$distutildir"/chdkptp-dist.sh  "$stagedir"/chdkptp.sh
	if [ ! -z "$gui" ] ; then
		cp "$distutildir"/chdkptp_gui-dist.sh  "$stagedir"/chdkptp_gui.sh
	fi
fi
if [ ! -z "$liblist" ] ; then
	mkdir -p "$stagedir"/lib
	for libfile in $liblist ; do
		cp "$libroot/$libfile" "$stagedir"/lib || error_exit "lib copy $libfile failed"
	done
	if [ "$OS" = "Linux" -a -z "$debug" ] ; then
		strip "$stagedir"/lib/*.so
	fi
	cp "$libroot/iup/COPYRIGHT" "$stagedir"/lib/IUP-COPYRIGHT
	cp "$libroot/cd/COPYRIGHT" "$stagedir"/lib/CD-COPYRIGHT
fi
zip -r "$ZIPNAME" "$stagedir"
