
case $1 in
	arm)
		export STAGING_DIR=/opt/OpenWrt-SDK-c300v2evm-for-Linux-i686-gcc-4.5.4_uClibc-0.9.33.2/staging_dir
		export STAGING_USR=$STAGING_DIR/target-arm_v4t_uClibc-0.9.33.2_eabi/usr
		export CCPREFIX=$STAGING_DIR/toolchain-arm_v4t_gcc-4.5.4_uClibc-0.9.33.2_eabi  
		export config_TARGET_CC=$CCPREFIX/bin/arm-openwrt-linux-gcc	
		export config_BUILD_CC="gcc"
		export CC_FOR_BUILD="gcc"; 
		export CC=$CCPREFIX/bin/arm-openwrt-linux-gcc
		export CXX=$CCPREFIX/bin/arm-openwrt-linux-g++
		export LD=$CCPREFIX/bin/arm-openwrt-linux-ld
		export CPP=$CCPREFIX/bin/arm-openwrt-linux-cpp
		export AR=$CCPREFIX/bin/arm-openwrt-linux-ar
		export STRIP=$CCPREFIX/bin/arm-openwrt-linux-strip
		export RANLIB=$CCPREFIX/bin/arm-openwrt-linux-ranlib

		mkdir -p lib
		rm -rf lib/*
		rm -f luci/template/*
		make clean
		make CFLAGS="-O2 -I$STAGING_USR/include" libbuild

		for luadir in src/* ; do
			if [ -d $luadir/dist/usr/lib/lua/luci/template ]; then
				cp $luadir/dist/usr/lib/lua/luci/template/* luci/template/
			else
				if [ -d $luadir/dist ]; then
					cp $luadir/dist/usr/lib/lua/*.so lib
				fi
				if [ -d $luadir/lua ]; then
					cp -r $luadir/lua/* lib
				fi
			fi


		done

		make clean

		;;
	s805-arm)
		export STAGING_DIR=
		export STAGING_USR=/opt/toolchains/gcc-linaro-arm-linux-gnueabihf-4.9-2014.09_linux/arm-linux-gnueabihf/
		export CCPREFIX=/opt/toolchains/gcc-linaro-arm-linux-gnueabihf-4.9-2014.09_linux
		export config_TARGET_CC=$CCPREFIX/bin/arm-linux-gnueabihf-gcc
		export config_BUILD_CC="gcc"
		export CC_FOR_BUILD_CC="arm-linux-gnueabihf-gcc";
		export CC_FOR_BUILD=$CCPREFIX/bin/arm-linux-gnueabihf-gcc
		export CC=$CCPREFIX/bin/arm-linux-gnueabihf-gcc
		export CXX=$CCPREFIX/bin/arm-linux-gnueabihf-g++
		export LD=$CCPREFIX/bin/arm-linux-gnueabihf-ld
		export CPP=$CCPREFIX/bin/arm-linux-gnueabihf-cpp
		export AR=$CCPREFIX/bin/arm-linux-gnueabihf-ar
		export STRIP=$CCPREFIX/bin/arm-linux-gnueabihf-strip
		export RANLIB=$CCPREFIX/bin/arm-linux-gnueabihf-ranlib

		mkdir -p lib
		rm -rf lib/*
		rm -f luci/template/*
		make clean
		make CFLAGS="-O2 -I$STAGING_USR/include" libbuild

		for luadir in src/* ; do
			if [ -d $luadir/dist/usr/lib/lua/luci/template ]; then
				cp $luadir/dist/usr/lib/lua/luci/template/* luci/template/
			else
				if [ -d $luadir/dist ]; then
					cp $luadir/dist/usr/lib/lua/*.so lib
				fi
				if [ -d $luadir/lua ]; then
					cp -r $luadir/lua/* lib
				fi
			fi


		done

		make clean

		;;
	mipsel)
		export STAGING_DIR=/home/samba/openwrt-uc100/staging_dir
		export STAGING_USR=$STAGING_DIR/target-mipsel_24kec+dsp_uClibc-0.9.33.2/usr
		export CCPREFIX=$STAGING_DIR/toolchain-mipsel_24kec+dsp_gcc-4.8-linaro_uClibc-0.9.33.2
		export config_TARGET_CC=$CCPREFIX/bin/mipsel-openwrt-linux-gcc
		export config_BUILD_CC="gcc"
		export CC_FOR_BUILD_CC="mipsel-openwrt-linux-gcc"
		export CC=$CCPREFIX/bin/mipsel-openwrt-linux-gcc
		export CXX=$CCPREFIX/bin/mipsel-openwrt-linux-g++
		export LD=$CCPREFIX/bin/mipsel-openwrt-linux-ld
		export CPP=$CCPREFIX/bin/mipsel-openwrt-linux-cpp
		export AR=$CCPREFIX/bin/mipsel-openwrt-linux-ar
		export STRIP=$CCPREFIX/bin/mipsel-openwrt-linux-strip
		export RANLIB=$CCPREFIX/bin/mipsel-openwrt-linux-ranlib

		mkdir -p lib
		rm -rf lib/*
		rm -f luci/template/*
		make clean
		make CFLAGS="-O2 -I$STAGING_USR/include" libbuild


		for luadir in src/* ; do
			if [ -d $luadir/dist/usr/lib/lua/luci/template ]; then
				cp $luadir/dist/usr/lib/lua/luci/template/* luci/template/
			else
				if [ -d $luadir/dist ]; then
					cp $luadir/dist/usr/lib/lua/*.so lib
				fi
				if [ -d $luadir/lua ]; then
					cp -r $luadir/lua/* lib
				fi
			fi

		done

		make clean

		;;
	x86)
		export CC=gcc

		./configure --with-apr=$libpath/$1 --with-aprutil=$libpath/$1 --with-dpr=$libpath/$1

		make
		;;
	*)
		;;
esac
