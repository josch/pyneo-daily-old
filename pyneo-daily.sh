#!/bin/sh -x

PYNEOREP="http://git.pyneo.org/browse/cgit/pyneo/"
PYNEOGIT="./pyneo-git"
PAROLIREP="http://git.pyneo.org/browse/cgit/paroli/"
PAROLIGIT="./paroli-git"
DATENOW=`date -u +%Y%m%d`
BUILD="./build"
DEBDIRS="./debian"
DSCDIR="./dsc"

setup()
{
	mkdir -p $BUILD $DEBDIRS $DSCDIR

	if [ -d "$PYNEOGIT" ]; then
		echo "$PYNEOGIT already exists - not cloning again"
	else
		git clone $PYNEOREP $PYNEOGIT || { echo "clone failed"; exit 1; }
	fi

	if [ -d "$PAROLIGIT" ]; then
		echo "$PAROLIGIT already exists - not cloning again"
	else
		git clone $PAROLIREP $PAROLIGIT || { echo "clone failed"; exit 1; }
	fi
}

run()
{
	[ ! -d $PYNEOGIT ] && { echo "no such directory: $PYNEOGIT"; exit 1; }

	if [ `( cd $PYNEOGIT; git ls-remote origin refs/heads/master; ) | awk '{print $1}'` != \
	     `( cd $PYNEOGIT; git show-ref refs/heads/master; ) | awk '{print $1}'` ]; then
		echo "new version available, pulling new changes"
		( cd $PYNEOGIT; git pull; ) || { echo "pulling failed"; exit 1; }
		buildpyneo
	else
		echo "nothing to update"
	fi
}

buildpyneo()
{
	[ ! -d $PYNEOGIT ] && { echo "no such directory: $PYNEOGIT"; exit 1; }
	[ ! -d $BUILD ] && { echo "no such directory: $BUILD"; exit 1; }
	[ ! -d $DSCDIR ] && { echo "no such directory: $DSCDIR"; exit 1; }

	for pkg in gsm0710muxd python-pyneo pyneo-resolvconf; do
		cp -r "$PYNEOGIT/$pkg" "$BUILD/$pkg-$DATENOW"
		tar --directory "$BUILD" --create --gzip --file "$BUILD/${pkg}_$DATENOW.orig.tar.gz" "$pkg-$DATENOW"
		cp -r "$DEBDIRS/$pkg-debian" "$BUILD/$pkg-$DATENOW/debian"
		DEBEMAIL="josch@pyneo.org" DEBFULLNAME="Johannes Schauer" dch --package "$pkg" --newversion "$DATENOW" --distribution unstable --empty --changelog "$BUILD/$pkg-$DATENOW/debian/changelog" --create "new nightly build"
		( cd "$BUILD/$pkg-$DATENOW"; dpkg-buildpackage -S -us -uc )
	done

	for pkg in pyneod pybankd; do
		cp -r "$PYNEOGIT/$pkg" "$BUILD/pyneo-$pkg-$DATENOW"
		tar --directory "$BUILD" --create --gzip --file "$BUILD/pyneo-${pkg}_$DATENOW.orig.tar.gz" "pyneo-$pkg-$DATENOW"
		cp -r "$DEBDIRS/pyneo-$pkg-debian" "$BUILD/pyneo-$pkg-$DATENOW/debian"
		DEBEMAIL="josch@pyneo.org" DEBFULLNAME="Johannes Schauer" dch --package "pyneo-$pkg" --newversion "$DATENOW" --distribution unstable --empty --changelog "$BUILD/pyneo-$pkg-$DATENOW/debian/changelog" --create "new nightly build"
		( cd "$BUILD/pyneo-$pkg-$DATENOW"; dpkg-buildpackage -S -us -uc )
	done
	mv $BUILD/*_* "$DSCDIR"
	rm -rf $BUILD/*
}

fullclean()
{
	rm -rf $BUILD/*
	rm -rf $DSCDIR/*
	rm -rf $PYNEOGIT
	rm -rf $PAROLIGIT
}

if [ $# -eq 0 ]; then
	echo "no arguments supplied"
	exit 0
else
	for arg in $@; do
		case $arg in
			setup)
				echo "doing setup"
				setup
				;;
			build)
				echo "building packages"
				buildpyneo
				;;
			buildpyneo)
				echo "building pyneo"
				buildpyneo
				;;
			fullclean)
				echo "cleaning"
				fullclean
				;;
			run)
				echo "doing run"
				run
				;;
			*)
				echo "unknown arg $arg"
				exit 1
		esac
	done
fi
