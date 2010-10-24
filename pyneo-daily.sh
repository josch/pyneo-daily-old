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
	mkdir -p $BUILD $DSCDIR

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

	#TODO: check paroli repository
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

buildparoli()
{
	[ ! -d $PAROLIGIT ] && { echo "no such directory: $PAROLIGIT"; exit 1; }
	[ ! -d $BUILD ] && { echo "no such directory: $BUILD"; exit 1; }
	[ ! -d $DSCDIR ] && { echo "no such directory: $DSCDIR"; exit 1; }

	for pkg in ijon; do
		cp -r "$PAROLIGIT/$pkg" "$BUILD/python-$pkg-$DATENOW"
		tar --directory "$BUILD" --create --gzip --file "$BUILD/python-${pkg}_$DATENOW.orig.tar.gz" "python-$pkg-$DATENOW"
		cp -r "$DEBDIRS/python-$pkg-debian" "$BUILD/python-$pkg-$DATENOW/debian"
		DEBEMAIL="josch@pyneo.org" DEBFULLNAME="Johannes Schauer" dch --package "python-$pkg" --newversion "$DATENOW" --distribution unstable --empty --changelog "$BUILD/python-$pkg-$DATENOW/debian/changelog" --create "new nightly build"
		( cd "$BUILD/python-$pkg-$DATENOW"; dpkg-buildpackage -S -us -uc )
	done
	mv $BUILD/*_* "$DSCDIR"
	rm -rf $BUILD/*
}

fullclean()
{
	rm -rf $BUILD
	rm -rf $DSCDIR
	rm -rf $PYNEOGIT
	rm -rf $PAROLIGIT
}

usage()
{
	echo "usage: ./pyneo-daily ARG"
	echo " setup       does an intial setup"
	echo " run         updates git and if new versions are available, runs buildpyneo"
	echo "             and buildparoli accordingly"
	echo " buildall    runs buildpyneo and buildparoli"
	echo " buildpyneo  builds pyneo deb source packages from current git version"
	echo " buildparoli builds paroli deb source packages from current git version"
	echo " fullclean   removes build directory, source packages and git repositories"
	exit 0
}

if [ $# -eq 0 ]; then
	usage
else
	for arg in $@; do
		case $arg in
			setup)
				echo "doing setup"
				setup
				;;
			buildall)
				echo "building packages"
				buildpyneo
				buildparoli
				;;
			buildpyneo)
				echo "building pyneo"
				buildpyneo
				;;
			buildparoli)
				echo "building paroli"
				buildparoli
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
				usage
		esac
	done
fi
