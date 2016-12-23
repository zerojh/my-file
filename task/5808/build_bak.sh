#!/bin/sh

    #release_ver=$1

	#获取lib库的信息,该函数只针对生成了pkgconfig信息的库
	get_pc_var()
	{
		echo `cat $1/lib/pkgconfig/$2 | grep $3 | awk -F': ' '{ printf tolower($2) }'`
	}

	#获取git库当前的最新commit的hash值作为版本号之一,主要是用于第三方开源库
	get_git_ver()
	{
		echo `git log --pretty=format:%h -n1 | awk -F': ' '{ printf $1 }'`
	}

	#填充opkg的control文件信息
	build_opkg_control()
	{
		local ctrlfile="$1"
		local name="$2"
		local ver="$3"
		local sec="$4"
		local prio="$5"
		local arch="$6"
		local desc="$7"
		local src="$8"
		local dep=""
		local conf=""

		if [ $# -gt 8 ]; then
			dep=$9
		fi
		if [ $# -gt 9 ]; then
			conf=$10
		fi

		cp $controlfile $ctrlfile

		sed -i "s/<name>/$name/g" $ctrlfile
		sed -i "s/<ver>/$ver/g" $ctrlfile
		sed -i "s/<sec>/$sec/g" $ctrlfile
		sed -i "s/<prio>/$prio/g" $ctrlfile
		sed -i "s/<arch>/$arch/g" $ctrlfile
		sed -i "s/<desc>/$desc/g" $ctrlfile
		sed -i "s/<src>/$src/g" $ctrlfile
		#sed -i "s/<dep>/$dep/g" $ctrlfile
		sed -i "s/<dep>/""/g" $ctrlfile
		sed -i "s/<conf>/$conf/g" $ctrlfile

	}

	build_opkg_script()
	{
		local ctrldir=$1
		shift
		local srvdir=$1
		shift
		local bin=$1
		shift
		local start=$1
		shift
		local stop=$1
		shift
		local args="$@"


		#准备启动脚本
		cp $controldir/preinst $ctrldir/preinst
        sed -i "s/<_bin_>/$bin/g" $ctrldir/preinst

		cp $controldir/postinst $ctrldir/postinst
		sed -i "s/<_bin_>/$bin/g" $ctrldir/postinst

		cp $controldir/prerm $ctrldir/prerm
		sed -i "s/<_bin_>/$bin/g" $ctrldir/prerm

		cp $controldir/postrm $ctrldir/postrm
		sed -i "s/<_confdir_>/\/etc\/$bin/g" $ctrldir/postrm

		cp $servicefile $srvdir/$bin
		sed -i "s/<_start_>/$start/g" $srvdir/$bin
		sed -i "s/<_stop_>/$stop/g" $srvdir/$bin
		sed -i "s/<_bin_>/\/bin\/$bin/g" $srvdir/$bin
		sed -i "s/<_pid_>/\/var\/run\/$bin.pid/g" $srvdir/$bin
		sed -i "s/<_arg_>/\"$args\"/g" $srvdir/$bin
	}



	build_opkg_package()
	{
		local tmp_dir=$1
		local restore_dir=$2
		cd $tmp_dir
		
		if [ "no" != ${stripflag} ]; then
			if [ -d bin ]; then
				`${STRIP} bin/*`
			fi
			
			if [ -d usr/bin ]; then
				`${STRIP} usr/bin/*`
			fi
			
			if [ -d lib ]; then
				`${STRIP} lib/*`
			fi
			
			if [ -d lib/fsmod ]; then
				`${STRIP} lib/fsmod/*`
			fi
		fi
		
		cd ..
		$opkgbuild  $tmp_dir ./
		rm -rf $tmp_dir

		local filename=`ls *.ipk`
		echo "${filename}" >> $packagedir/ipklist
		mv $filename $packagedir
		cd $restore_dir
	}

	#通用的build动作处理函数
	build_general()
	{
	   local ret
		local action=$1
		case $action in
			configure)
				if [ -f configure ] ;then
					./configure $quiet $2 CFLAGS="$3" LDFLAGS="$4" CXXFLAGS="$5"
					ret=$?
				else
					ret=0
				fi
				;;
			build)
				make $quiet
				ret=$?
				;;
			install)
				make install
				ret=$?
				;;
			uninstall)
				make uninstall
				ret=0
				;;
			clean)
				make clean
				ret=$?
				;;
			distclean)
				make distclean
				ret=$?
				;;
			gitclean)
				#git clean -x -f -d
				ret=0
				;;
			*)
			     ret=0
				;;
		esac

		if [ 0 -ne $ret ] ; then
		  exit
		fi
	}
	
	build_zmq()
	{
		case $1 in
			bootstrap)
				./autogen.sh
				;;
			opkg)

				local tmpsrc="lib-zmq git `get_git_ver`"
				local pcname=libzmq.pc
				local tmpname=$tmpdir/opkg/zmq
				local tmplib=$tmpname/lib
				local tmpctrl=$tmpname/CONTROL
				mkdir -p $tmplib
				mkdir -p $tmpctrl

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"libzmq" \
				"`get_pc_var $libdir $pcname Version`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"zmq" \
				"$tmpsrc" \
				"`get_pc_var $libdir $pcname Requires`"

				cp $libdir/lib/libzmq.so.3.1.0 $tmplib
				cd $tmplib
				ln -s libzmq.so.3.1.0 libzmq.so.3
				ln -s libzmq.so.3.1.0 libzmq.so

				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}
	build_czmq()
	{
		case $1 in
			bootstrap)
				autoreconf -f -i
				;;
			opkg)
				local curpwd=`pwd`
				local tmpsrc="lib-czmq git `get_git_ver`"
				local pcname=libczmq.pc
				local tmpname=$tmpdir/opkg/czmq
				local tmplib=$tmpname/lib
				local tmpctrl=$tmpname/CONTROL
				mkdir -p $tmplib
				mkdir -p $tmpctrl

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"libczmq" \
				"`get_pc_var $libdir $pcname Version`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"czmq" \
				"$tmpsrc" \
				"`get_pc_var $libdir $pcname Requires`"

				cp $libdir/lib/libczmq.so.1.1.0 $tmplib
				cd $tmplib
				ln -s libczmq.so.1.1.0 libczmq.so.1
				ln -s libczmq.so.1.1.0 libczmq.so

				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}

	build_pbc()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="lib-pbc git `get_git_ver`"
				local tmpname=$tmpdir/opkg/pbc
				local tmplib=$tmpname/lib
				local tmpctrl=$tmpname/CONTROL
				mkdir -p $tmplib
				mkdir -p $tmpctrl

				#pbc没有版本号,用git commit代替
				build_opkg_control "$tmpctrl/control" \
				"libpbc" \
				"1.0-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"Protocol buffer statck" \
				"$tmpsrc"

				cp $libdir/lib/libpbc.so $tmplib

				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}

	build_bind()
	{
		local action=$1
		case $action in
			build)
				export CFLAGS="$3"
				export LDFLAGS="$4"
				make $quiet
				ret=$?
				;;
			install)
                cp dpr.so $libdir/lib/
                cp mxml.so $libdir/lib/
                ret=$?
                ;;
            clean)
                make clean
                ret=$?
                ;;
			opkg)
                local curpwd=`pwd`
                local tmpsrc="lua-bind git `get_git_ver`"
                local tmpname=$tmpdir/opkg/lua
                local tmplib=$tmpname/usr/lib/lua
                local tmpctrl=$tmpname/CONTROL
                mkdir -p $tmplib
                mkdir -p $tmpctrl

                #提取版本号
                build_opkg_control "$tmpctrl/control" \
                "luabind" \
                "1.0.0-`date +%y%m%d%H%M`" \
                "misc" \
                "optional" \
                "$buildarch" \
                "mxml dpr bind for lua" \
                "$tmpsrc" \
                "libdpr libmxml"

                cp $libdir/lib/dpr.so $tmplib
                cp $libdir/lib/mxml.so $tmplib
                cp $confdir/../ini.lua $tmplib

                build_opkg_package $tmpname $curpwd

                ret=0
                ;;
			*)
				build_general "$@"
			    ret=0
				;;
		esac

		if [ 0 -ne $ret ] ; then
		  exit
		fi
	}

	build_minixml()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="lib-mxml git `get_git_ver`"
				local pcname=mxml.pc
				local tmpname=$tmpdir/opkg/mxml
				local tmplib=$tmpname/lib
				local tmpctrl=$tmpname/CONTROL
				mkdir -p $tmplib
				mkdir -p $tmpctrl

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"libmxml" \
				"`get_pc_var $libdir $pcname Version`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"`get_pc_var $libdir $pcname Description`" \
				"$tmpsrc" \
				"`get_pc_var $libdir $pcname Requires`"

				cp $libdir/lib/libmxml.so.1.5 $tmplib
				cd $tmplib
				ln -s libmxml.so.1.5 libmxml.so.1
				ln -s libmxml.so.1.5 libmxml.so

				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}

	build_expat()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="lib-expat git `get_git_ver`"
				local pcname=expat.pc
				local tmpname=$tmpdir/opkg/expat
				local tmplib=$tmpname/lib
				local tmpctrl=$tmpname/CONTROL
				mkdir -p $tmplib
				mkdir -p $tmpctrl

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"libexpat" \
				"`get_pc_var $libdir $pcname Version`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"`get_pc_var $libdir $pcname Description`" \
				"$tmpsrc" \
				"`get_pc_var $libdir $pcname Requires`"

				cp $libdir/lib/libexpat.so.1.6.0 $tmplib
				cd $tmplib
				ln -s libexpat.so.1.6.0 libexpat.so.1
				ln -s libexpat.so.1.6.0 libexpat.so

				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}

	build_apr()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="lib-apr git `get_git_ver`"
				local pcname=apr-1.pc
				local tmpname=$tmpdir/opkg/apr
				local tmplib=$tmpname/lib
				local tmpctrl=$tmpname/CONTROL
				mkdir -p $tmplib
				mkdir -p $tmpctrl

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"libapr" \
				"`get_pc_var $libdir $pcname Version`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"`get_pc_var $libdir $pcname Description`" \
				"$tmpsrc" \
				"`get_pc_var $libdir $pcname Requires`"

				cp $libdir/lib/libapr-1.so.0.5.1 $tmplib
				cd $tmplib
				ln -s libapr-1.so.0.5.1 libapr-1.so.0
				ln -s libapr-1.so.0.5.1 libapr-1.so

				build_opkg_package $tmpname $curpwd
				;;
			bootstrap)
				autoreconf -f -i
				;;
			*)
				build_general "$@"
				;;
		esac
	}

	build_aprutil()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="lib-aprutil git `get_git_ver`"
				local pcname=apr-util-1.pc
				local tmpname=$tmpdir/opkg/aprutil
				local tmplib=$tmpname/lib
				local tmpctrl=$tmpname/CONTROL
				mkdir -p $tmplib
				mkdir -p $tmpctrl

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"libaprutil" \
				"`get_pc_var $libdir $pcname Version`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"`get_pc_var $libdir $pcname Description`" \
				"$tmpsrc" \
				"libapr libexpat"

				cp $libdir/lib/libaprutil-1.so.0.5.4 $tmplib
				cd $tmplib
				ln -s libaprutil-1.so.0.5.4 libaprutil-1.so.0
				ln -s libaprutil-1.so.0.5.4 libaprutil-1.so

				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}

	build_pcre()
	{
		case $1 in
			bootstrap)
				autoreconf
				;;
			opkg)
				local curpwd=`pwd`
				local tmpsrc="lib-pcre git `get_git_ver`"
				local pcname=libpcre.pc
				local tmpname=$tmpdir/opkg/pcre
				local tmplib=$tmpname/lib
				local tmpctrl=$tmpname/CONTROL
				mkdir -p $tmplib
				mkdir -p $tmpctrl

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"libpcre" \
				"`get_pc_var $libdir $pcname Version`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"pcre" \
				"$tmpsrc"

				cp $libdir/lib/libpcre.so.1.2.3 $tmplib
				cd $tmplib
				ln -s libpcre.so.1.2.3 libpcre.so.1
				ln -s libpcre.so.1.2.3 libpcre.so

				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}

	build_curl()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="lib-curl git `get_git_ver`"
				local pcname=libcurl.pc
				local tmpname=$tmpdir/opkg/curl
				local tmplib=$tmpname/lib
				local tmpctrl=$tmpname/CONTROL
				mkdir -p $tmplib
				mkdir -p $tmpctrl

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"libcurl" \
				"`get_pc_var $libdir $pcname Version`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"curl" \
				"$tmpsrc" \
				"`get_pc_var $libdir $pcname Requires`"

				cp $libdir/lib/libcurl.so.4.3.0 $tmplib
				cd $tmplib
				ln -s libcurl.so.4.3.0 libcurl.so.4
				ln -s libcurl.so.4.3.0 libcurl.so

				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}

	build_sqlite()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="lib-sqlite git `get_git_ver`"
				local pcname=sqlite3.pc
				local tmpname=$tmpdir/opkg/sqlite
				local tmplib=$tmpname/lib
				local tmpctrl=$tmpname/CONTROL
				mkdir -p $tmplib
				mkdir -p $tmpctrl

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"libsqlite3" \
				"`get_pc_var $libdir $pcname Version`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"sqlite" \
				"$tmpsrc" \
				"`get_pc_var $libdir $pcname Requires`"

				cp $libdir/lib/libsqlite3.so.0.8.6 $tmplib
				cd $tmplib
				ln -s libsqlite3.so.0.8.6 libsqlite3.so.0
				ln -s libsqlite3.so.0.8.6 libsqlite3.so

				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}
	
	build_speex()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="lib-speex git `get_git_ver`"
				local pcname=speex.pc
				local tmpname=$tmpdir/opkg/speex
				local tmplib=$tmpname/lib
				local tmpctrl=$tmpname/CONTROL
				mkdir -p $tmplib
				mkdir -p $tmpctrl

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"libspeex" \
				"`get_pc_var $libdir $pcname Version`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"speex" \
				"$tmpsrc" \
				"`get_pc_var $libdir $pcname Requires`"

				cp $libdir/lib/libspeex.so.1.5.0 $tmplib
				cp $libdir/lib/libspeexdsp.so.1.5.0 $tmplib
				cd $tmplib
				ln -s libspeexdsp.so.1.5.0 libspeexdsp.so.1
				ln -s libspeex.so.1.5.0 libspeex.so.1
				
				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}
	
	build_ogg()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="lib-ogg git `get_git_ver`"
				local pcname=ogg.pc
				local tmpname=$tmpdir/opkg/ogg
				local tmplib=$tmpname/lib
				local tmpctrl=$tmpname/CONTROL
				mkdir -p $tmplib
				mkdir -p $tmpctrl

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"libogg" \
				"`get_pc_var $libdir $pcname Version`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"ogg" \
				"$tmpsrc" \
				"`get_pc_var $libdir $pcname Requires`"

				cp $libdir/lib/libogg.so.0.8.1 $tmplib
				cd $tmplib
				ln -s libogg.so.0.8.1 libogg.so.0
				ln -s libogg.so.0.8.1 libogg.so
				
				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}
	
	build_openssl()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="lib-openssl git `get_git_ver`"
				local pcname=openssl.pc
				local tmpname=$tmpdir/opkg/openssl
				local tmplib=$tmpname/usr/lib
				local tmpctrl=$tmpname/CONTROL
				mkdir -p $tmplib
				mkdir -p $tmpctrl

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"libopenssl" \
				"`get_pc_var $syslibdir $pcname Version`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"openssl" \
				"$tmpsrc" \
				"`get_pc_var $syslibdir $pcname Requires`"

				cp $syslibdir/lib/libcrypto.so.1.0.0 $tmplib
				cp $syslibdir/lib/libssl.so.1.0.0 $tmplib
				cd $tmplib
				ln -s libcrypto.so.1.0.0 libcrypto.so.0
				ln -s libssl.so.1.0.0 libssl.so.0
				
				build_opkg_package $tmpname $curpwd
				;;
			*)
				;;
		esac
	}

	build_opkg_lua_web_script()
	{
		local ctrldir=$1

		#./buildlib.sh $cpu
		#准备启动脚本
		cp build/postinst $ctrldir/postinst

		cp build/prerm $ctrldir/prerm

		cp build/postrm $ctrldir/postrm
		
		cp build/preinst $ctrldir/preinst
	}

	build_factorytest_client()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="oem git `get_git_ver`"
				local tmpname=$tmpdir/opkg/factorytest-client
				local tmpctrl=$tmpname/CONTROL
				local tmpconf=$tmpname$firmware_upgrading_temp_dir/
				local tmpbin=$tmpconf/factorytest-client/usr/bin/
				local tmpbtn=$tmpconf/factorytest-client/etc/rc.button/

				mkdir -p $tmpctrl
				mkdir -p $tmpconf
				mkdir -p $tmpbin
				mkdir -p $tmpbtn

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"factorytest-client" \
				"1.0-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"factorytest-client" \
				"$tmpsrc" \
				""

				cp factory_test* $tmpbin
				cp BTN_* $tmpbtn
				cp preinst $tmpctrl
				cp postinst $tmpctrl

				local stripflag_bak=${stripflag}
				stripflag="no"
				build_opkg_package $tmpname $curpwd
				stripflag=stripflag_bak
				;;
			*)
				;;
		esac
	}

	build_oem_info()
	{

		local curpwd=`pwd`
		local tmpsrc="oem git `get_git_ver`"
		local tmpname=$tmpdir/opkg/oem
		local tmpctrl=$tmpname/CONTROL
		local tmpconf=$tmpname$firmware_upgrading_temp_dir/oem

		mkdir -p $tmpctrl
		mkdir -p $tmpconf

		#提取版本号
		build_opkg_control "$tmpctrl/control" \
		"oem" \
		"1.0-`echo ${brand} | tr '/' '-'`-`date +%y%m%d%H%M`" \
		"misc" \
		"optional" \
		"$buildarch" \
		"oem" \
		"$tmpsrc" \
		""

		if [ "bluewave/WP1" == ${brand} ]; then
			cp oem_database/bluewave/WP1/bin/network_watch $tmpconf
			cp oem_database/bluewave/WP1/bin/restore_default $tmpconf
			cp oem_database/bluewave/WP1/oem $tmpconf
			cp oem_database/bluewave/WP1/bluewave_logo.png $tmpconf
			cp oem_database/bluewave/WP1/etc $tmpconf -rf
			cp oem_database/bluewave/WP1/postinst $tmpctrl
			cp oem_database/bluewave/WP1/postrm $tmpctrl
		elif [ "bluewave/S5V" == ${brand} ]; then
			cp oem_database/bluewave/S5V/network_watch $tmpconf
			cp oem_database/bluewave/S5V/oem $tmpconf
			cp oem_database/bluewave/S5V/bluewave_logo.png $tmpconf
			cp oem_database/bluewave/S5V/system_custom.lua $tmpconf
			cp oem_database/bluewave/S5V/led.lua $tmpconf
			cp oem_database/bluewave/S5V/postinst $tmpctrl
			cp oem_database/bluewave/S5V/postrm $tmpctrl
		elif [ "dchy" == ${brand} ]; then
			cp oem_database/dchy/oem $tmpconf
			cp oem_database/dchy/bin $tmpconf -rf
			cp oem_database/dchy/etc $tmpconf -rf
			cp oem_database/dchy/icons $tmpconf -rf
			cp oem_database/dchy/lib $tmpconf -rf
			cp oem_database/dchy/luci $tmpconf -rf
			cp oem_database/dchy/usr $tmpctrl -rf
			cp oem_database/dchy/postinst $tmpctrl
			cp oem_database/dchy/postrm $tmpctrl
		else
			cp oem_database/${brand}/oem $tmpconf
			if [ "cn" == ${lang} ]; then
				sed -i "s/option 'lang' 'en'/option 'lang' 'cn'/g" $tmpconf/oem
				sed -i "s/option 'timezone' 'GMT0'/option 'timezone' 'CST-8'/g" $tmpconf/oem
				sed -i "s/option 'zonename' 'UTC'/option 'zonename' 'Asia\/Beijing'/g" $tmpconf/oem
			fi
			if [ -f oem_database/${brand}/${brand}_logo.png ]; then
				cp oem_database/${brand}/${brand}_logo.png $tmpconf
			fi

			echo "#!/bin/sh" >> $tmpctrl/postinst
			chmod +x $tmpctrl/postinst

			#准备安装脚本
cat >>$tmpctrl/postinst << EOF 
cp $firmware_upgrading_temp_dir/oem/oem /etc/config/oem
if [ -f $firmware_upgrading_temp_dir/oem/${brand}_logo.png ]; then
	cp $firmware_upgrading_temp_dir/oem/${brand}_logo.png /www/luci-static/resources/
fi
sed -i '/^\/tmp\//d' /usr/lib/opkg/info/oem.list
/etc/init.d/lucid restart&
EOF
			echo "#!/bin/sh" >> $tmpctrl/preinst
			chmod +x $tmpctrl/preinst
			#opkg install oem.ipk 若之前安装过oem，install的话,其postrm脚本并不会执行，prerm和postrm只有在 opkg remove时才会执行，
			#若从某些第三方oem定制重刷到dinstar或中性等版本，就会导致因为没执行postrm从而导致第三方oem信息清理不干净的问题
			#若直接在oem.preinst里执行opkg remove oem，opkg会报错的，所以这里用-f判断该脚本是否存在，手动执行
cat >>$tmpctrl/preinst << EOF
if [ -f "/usr/lib/opkg/info/oem.postrm" ]; then
	sh /usr/lib/opkg/info/oem.postrm >>/dev/null 2>&1
fi
EOF
		fi
		build_opkg_package $tmpname $curpwd
	}
	build_lua_web()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="lua-web git `get_git_ver`"
				local tmpname=$tmpdir/opkg/luci
				local tmplib=$tmpname$firmware_upgrading_temp_dir/luci/usr/lib/lua
				local tmpwww=$tmpname$firmware_upgrading_temp_dir/luci/www
				local tmpctrl=$tmpname/CONTROL
				local tmpconf=$tmpname$firmware_upgrading_temp_dir/luci/etc
				local tmpsrv=$tmpname$firmware_upgrading_temp_dir/luci/etc/init.d

				mkdir -p $tmpsrv
				mkdir -p $tmplib
				mkdir -p $tmpctrl
				mkdir -p $tmpwww
				mkdir -p $tmpconf

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"luci" \
				"1.0-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"luci" \
				"$tmpsrc" \
				""

				#准备安装脚本
				build_opkg_lua_web_script $tmpctrl


				cp -r luci $tmplib
				cp -r lib/* $tmplib
				cp $syslibdir/lib/ESL.so $tmplib
				cp $syslibdir/lib/lsqlite3.so $tmplib
				cp -r www/* $tmpwww
				cp -r etc/* $tmpconf

				if [ "dinstar" == "${brand}" -a "1." == ${version:0:2} ]; then
					brand="unknown"
				fi

				build_opkg_package $tmpname $curpwd

				if [ ! -z ${brand} ]; then
					build_oem_info
				fi
				;;
			*)
				;;
		esac
	}

	build_vpn()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpname=$tmpdir/opkg/vpn
				local tmpctrl=$tmpname/CONTROL
				local tmpsrv=$tmpname$firmware_upgrading_temp_dir/vpn

				mkdir -p $tmpname
				mkdir -p $tmpctrl
				mkdir -p $tmpsrv

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"vpn" \
				"1.0-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"vpn" \
				"vpn" \
				""

				#准备安装脚本
				cp -r lib $tmpsrv
				cp -r etc $tmpsrv
				cp -r usr $tmpsrv
				cp preinst $tmpctrl
				cp postinst $tmpctrl
				
				build_opkg_package $tmpname $curpwd
				;;
			*)
				;;
		esac
	}
	
	build_cloud()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="cloud git `get_git_ver`" || ""
				local tmpname=$tmpdir/opkg/cloud
				local tmpctrl=$tmpname/CONTROL
				local tmpsbin=$tmpname$firmware_upgrading_temp_dir/cloud/usr/sbin
				local tmpinitd=$tmpname$firmware_upgrading_temp_dir/cloud/etc/init.d

				mkdir -p $tmpinitd
				mkdir -p $tmpsbin
				mkdir -p $tmpctrl

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"cloud" \
				"1.0-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"cloud" \
				"$tmpsrc" \
				""

				#准备安装脚本
				build_opkg_script $tmpctrl $tmpinitd cloud 99 99 ""	
				
				cp $prebindir/cloud/cloud $tmpsbin
				cp $prebindir/cloud/remoted $tmpsbin
				cp $sourcedir/cloud/etc $tmpname -r
				cp $sourcedir/cloud/preinst $tmpctrl
				cp $sourcedir/cloud/postinst $tmpctrl

				build_opkg_package $tmpname $curpwd
				;;
			build)
				make CFLAGS="$3" LDFLAGS="$4" CXXFLAGS="$5" BINDIR="$bindir/cloud"
				;;
			*)
				;;
		esac
	}

	build_tr069()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="tr069 git `get_git_ver`" || ""
				local tmpname=$tmpdir/opkg/tr069
				local tmpctrl=$tmpname/CONTROL
				local tmpsrv=$tmpname$firmware_upgrading_temp_dir/tr069
				local tmpinitd=$tmpsrv/etc/init.d

				mkdir -p $tmpctrl
				mkdir -p $tmpsrv
				mkdir -p $tmpinitd

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"tr069" \
				"1.0-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"tr069" \
				"$tmpsrc" \
				""
				
				build_opkg_script $tmpctrl $tmpinitd easycwmp 99 99 ""

				cp control/* $tmpctrl
				cp etc $tmpsrv -rf
				cp usr $tmpsrv -rf

				build_opkg_package $tmpname $curpwd
				;;
			build)
				#make CFLAGS="$3" LDFLAGS="$4" CXXFLAGS="$5" BINDIR="$bindir/tr069"
				;;
			*)
				;;
		esac
	}
	
	build_sounds()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="sounds git `get_git_ver`"
				local tmpname=$tmpdir/opkg/sounds
				local tmpctrl=$tmpname/CONTROL
				local tmpconf=$tmpname$firmware_upgrading_temp_dir/sounds/etc/freeswitch/sounds

				mkdir -p $tmpctrl
				mkdir -p $tmpconf

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"sounds" \
				"1.0-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"sounds" \
				"$tmpsrc" \
				""

				#准备安装脚本
				cp preinst $tmpctrl
				cp postinst $tmpctrl
				if [ "cn" == ${lang} ]; then
					cp -r $soundsdir/zh $tmpconf
				else
					cp -r $soundsdir/en $tmpconf
				fi
				
				build_opkg_package $tmpname $curpwd
				;;
			*)
				;;
		esac
	}
	
	build_dsp()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="dsp git `get_git_ver`"
				local tmpname=$tmpdir/opkg/dsp
				local tmpctrl=$tmpname/CONTROL
				local tmpconf=$tmpname$firmware_upgrading_temp_dir/dsp/
				
				mkdir -p $tmpctrl
				mkdir -p $tmpconf
				
				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"dsp" \
				"1.0-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"dsp" \
				"$tmpsrc" \
				""

				#准备安装脚本
				cp $dspdir/dsp $tmpconf
				cp $dspdir/ralink_pcm.ko $tmpconf
				cp $dspdir/preinst $tmpctrl
				cp $dspdir/postinst $tmpctrl
				
				build_opkg_package $tmpname $curpwd
				;;
			*)
				;;
		esac
	}

	build_edit()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="lib-edit git `get_git_ver`"
				local pcname=libedit.pc
				local tmpname=$tmpdir/opkg/edit
				local tmplib=$tmpname/lib
				local tmpctrl=$tmpname/CONTROL
				mkdir -p $tmplib
				mkdir -p $tmpctrl

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"libedit" \
				"`get_pc_var $libdir $pcname Version`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"edit" \
				"$tmpsrc" \
				"`get_pc_var $libdir $pcname Requires`"

				cp $libdir/lib/libedit.so.0 $tmplib
				cd $tmplib
				ln -s libedit.so.0 libedit.so
				
				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}


	build_dpr()
	{
		case $1 in
			bootstrap)
				./bootstrap.sh
				;;
			opkg)
				local curpwd=`pwd`
				local tmpsrc="lib-dpr git `get_git_ver`"
				local pcname=libdpr.pc
				local tmpname=$tmpdir/opkg/dpr
				local tmplib=$tmpname/lib
				local tmpctrl=$tmpname/CONTROL
				mkdir -p $tmplib
				mkdir -p $tmpctrl

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"libdpr" \
				"`get_pc_var $libdir $pcname Version`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"`get_pc_var $libdir $pcname Description`" \
				"$tmpsrc" \
				"libapr libexpat libaprutil libmxml libpbc libzmq libczmq"

				cp $libdir/lib/libdpr.so.0.0.0 $tmplib
				cd $tmplib
				ln -s libdpr.so.0.0.0 libdpr.so.0
				ln -s libdpr.so.0.0.0 libdpr.so

				build_opkg_package $tmpname $curpwd
				
				build_syslib $action
				;;
			*)
				build_general "$@"
				;;
		esac
	}

	build_syslib()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="lib-dsys git `get_git_ver`"
				local tmpname=$tmpdir/opkg/dsys
				local tmplib=$tmpname/lib
				local tmpctrl=$tmpname/CONTROL
				mkdir -p $tmplib
				mkdir -p $tmpctrl

				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"libdsys" \
				"1.0-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"Dpr System Library" \
				"$tmpsrc" \
				"libdpr"

				cp $syslibdir/lib/libdsys.so.0.0.0 $tmplib
				cd $tmplib
				ln -s libdsys.so.0.0.0 libdsys.so.0
				ln -s libdsys.so.0.0.0 libdsys.so

				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}
	
	


	

	build_cli()
	{
		case $1 in
			opkg)
				local curpwd=`pwd`
				local tmpsrc="klish git `get_git_ver`"
				local tmpname=$tmpdir/opkg/cli
				local tmplib=$tmpname/lib
				local tmpbin=$tmpname/bin
				local tmpcfg=$tmpname/etc/cli
				local tmpctrl=$tmpname/CONTROL
				local tmpsrv=$tmpname/etc/init.d

				mkdir -p $tmpsrv
				mkdir -p $tmplib
				mkdir -p $tmpbin
				mkdir -p $tmpctrl
				mkdir -p $tmpcfg


				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"cli" \
				"1.6.6-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"Klish Command Line Interface" \
				"$tmpsrc" \
				"libapr libexpat libaprutil libmxml libpbc libzmq libczmq libdsys libdpr"

				#build_opkg_script $tmpctrl $tmpsrv cli 99 15 "-x \/etc\/cli"

				cp $confdir/etc/cli/* $tmpcfg
				cp $bindir/cli/bin/clish $tmpbin/cli
				cp $bindir/cli/lib/libtinyrl.so.1.0.0 $tmplib
				cp $bindir/cli/lib/libclish.so.1.0.0 $tmplib
				cp $bindir/cli/lib/libkonf.so.1.0.0 $tmplib
				cp $bindir/cli/lib/liblub.so.1.0.0 $tmplib
				cp $bindir/cli/lib/clish_plugin_clish.so $tmplib
				cp $bindir/cli/lib/clish_plugin_lua.so $tmplib

				cd $tmplib
				ln -s libtinyrl.so.1.0.0 libtinyrl.so.1
				ln -s libtinyrl.so.1.0.0 libtinyrl.so
				ln -s libclish.so.1.0.0 libclish.so.1
				ln -s libclish.so.1.0.0 libclish.so
				ln -s libkonf.so.1.0.0 libkonf.so.1
				ln -s libkonf.so.1.0.0 libkonf.so
				ln -s liblub.so.1.0.0 liblub.so.1
				ln -s liblub.so.1.0.0 liblub.so


				build_opkg_package $tmpname $curpwd
				;;
			bootstrap)
			     ./autogen.sh
			     ;;
			*)
				build_general "$@"
				;;
		esac
	}

	build_freeswitch()
	{
		case $1 in
			bootstrap)
				./bootstrap.sh
				;;
			opkg)
				local curpwd=`pwd`
				local tmpsrc="freeswitch git `get_git_ver`"
				local pcname=freeswitch.pc
				local tmpname=$tmpdir/opkg/fs
				local tmpctrl=$tmpname/CONTROL
				local tmpinitd=$tmpname$firmware_upgrading_temp_dir/freeswitch/etc/init.d
				local tmpbin=$tmpname$firmware_upgrading_temp_dir/freeswitch/bin
				local tmpusrbin=$tmpname$firmware_upgrading_temp_dir/freeswitch/usr/bin
				local tmplib=$tmpname$firmware_upgrading_temp_dir/freeswitch/lib
				local tmpfsmod=$tmpname$firmware_upgrading_temp_dir/freeswitch/lib/fsmod
				local tmpetc=$tmpname$firmware_upgrading_temp_dir/freeswitch/etc/freeswitch

				mkdir -p $tmpinitd
				mkdir -p $tmpctrl


				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"freeswitch" \
				"1.4.12-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"Freeswitch" \
				"$tmpsrc" \
				"libapr libexpat libaprutil libcurl libpcre libsqlite3"

				#准备安装脚本
				build_opkg_script $tmpctrl 	$tmpinitd freeswitch 99 16 '-base \/etc\/freeswitch -conf \/etc\/freeswitch\/conf -db \/tmp\/fsdb -log \/var\/log -mod \/lib\/fsmod -nf -np -nc -nocal -product UC100-1G1S1O'

				mkdir -p $tmpbin
				cp $prebindir/freeswitch/bin/freeswitch $tmpbin
				cp $prebindir/freeswitch/bin/fs_cli $tmpbin
				cp $syslibdir/bin/audioconvert $tmpbin

				#lib放到lib目录
				mkdir -p $tmplib
				cp $prebindir/freeswitch/lib/libfreeswitch.so.1.0.0 $tmplib
				cp $prebindir/freeswitch/lib/libc300dsp.so.0.0.0 $tmplib
				cp $prebindir/freeswitch/lib/libfreetdm.so.1.0.0 $tmplib
				cp $prebindir/freeswitch/lib/libtrans.so.0.0.0 $tmplib
				cp $prebindir/freeswitch/lib/libc300cap.so.0.0.0 $tmplib

				#mod放到
				mkdir -p $tmpfsmod
				cp $prebindir/freeswitch/mod/*.so $tmpfsmod

				#需要保存的配置,都放到etc/freeswitch目录下
				mkdir -p $tmpetc/conf
				mkdir -p $tmpetc/grammar
				mkdir -p $tmpetc/scripts
				mkdir -p $tmpetc/sounds
				cp -R $confdir/etc/freeswitch/* $tmpetc/

				#生成软链接
				cd $tmplib
				ln -s libfreeswitch.so.1.0.0 libfreeswitch.so.1
				ln -s libfreeswitch.so.1.0.0 libfreeswitch.so

				ln -s libc300dsp.so.0.0.0 libc300dsp.so.0
				ln -s libc300dsp.so.0.0.0 libc300dsp.so

				ln -s libfreetdm.so.1.0.0 libfreetdm.so.1
				ln -s libfreetdm.so.1.0.0 libfreetdm.so

				ln -s libtrans.so.0.0.0 libtrans.so.0
				ln -s libtrans.so.0.0.0 libtrans.so

				ln -s libc300cap.so.0.0.0 libc300cap.so.0
				ln -s libc300cap.so.0.0.0 libc300cap.so

				if [ "no" != ${stripflag} ]; then
					`${STRIP} $tmpbin/*`
					`${STRIP} $tmplib/*`
					`${STRIP} $tmpfsmod/*`
				fi
				#add corn check app
				mkdir -p $tmpusrbin
				cp $confdir/etc/cron_app.sh $tmpusrbin
				chmod +x /$tmpusrbin/cron_app.sh
				cp $confdir/etc/cron_system.sh $tmpusrbin
				chmod +x /$tmpusrbin/cron_system.sh

				cat >>$tmpctrl/postrm << EOF 
if [ -f /etc/crontabs/root ]; then
	sed -i '/cron_app/d' /etc/crontabs/root
fi

opid=\`ps | grep -v grep | grep crond | awk '{print $1}'\`
if [ -n "\$opid" ]; then
	/etc/init.d/cron restart
fi

EOF
				cp $sourcedir/freeswitch/preinst $tmpctrl
				cp $sourcedir/freeswitch/postinst $tmpctrl

				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}

	build_provision()
	{
		case $1 in
			bootstrap)
				./bootstrap.sh
				;;
			opkg)
				local curpwd=`pwd`
				local tmpsrc="provision git `get_git_ver`"
				local tmpname=$tmpdir/opkg/prov
				local tmpbin=$tmpname/bin
				local tmpctrl=$tmpname/CONTROL
				local tmpcfg=$tmpname/etc/provision
				local tmpsrv=$tmpname/etc/init.d

				mkdir -p $tmpsrv
				mkdir -p $tmpbin
				mkdir -p $tmpctrl
				mkdir -p $tmpcfg


				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"provision" \
				"`./get-version.sh all src/provision.h PROV`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"Dinstar Provision Client" \
				"$tmpsrc" \
				"libapr libexpat libaprutil libmxml libpbc libzmq libczmq libdsys libdpr"

				#准备安装脚本
				build_opkg_script $tmpctrl 	$tmpsrv provision 96 17 '-d \/etc\/provision -s 32768'

				#保留原来的配置脚本
cat >>$tmpctrl/preinst << EOF 
if [ -f /etc/provision/provision.conf ]; then
	mkdir -p /tmp/prov/etc
	cp -r /etc/provision/* /tmp/prov/etc/
fi
EOF

cat >>$tmpctrl/postinst << EOF 
if [ -d /tmp/prov/etc ]; then
	if [ -f /tmp/prov/etc/service.lua ]; then
		rm /tmp/prov/etc/service.lua
	fi
	cp -r /tmp/prov/etc/* /etc/provision/
	rm -rf /tmp/prov/etc
	if [ -f /etc/provision/mod_log.conf ]; then
		rm /etc/provision/mod_log.conf
	fi
fi

EOF

				cp $bindir/provision/bin/provision $tmpbin
				cp $bindir/provision/etc/provision/* $tmpcfg

				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}
	build_rpcproxy()
	{
		case $1 in
			bootstrap)
				autoreconf -f -i
				;;
			opkg)
				local curpwd=`pwd`
				local tmpsrc="dprproxy git `get_git_ver`"
				local tmpname=$tmpdir/opkg/dprproxy
				local tmpbin=$tmpname/bin
				local tmpctrl=$tmpname/CONTROL
				local tmpcfg=$tmpname/etc/dprproxy
				local tmpsrv=$tmpname/etc/init.d
				mkdir -p $tmpbin
				mkdir -p $tmpctrl
				mkdir -p $tmpcfg
				mkdir -p $tmpsrv


				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"dprproxy" \
				"`./get-version.sh all src/dpr_proxy.h PROXY`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"Dinstar Internal Proxy" \
				"$tmpsrc" \
				"libapr libexpat libaprutil libmxml libpbc libzmq libczmq libdsys libdpr"

				#准备安装脚本
				build_opkg_script $tmpctrl 	$tmpsrv dprproxy 94 19 '-d \/etc\/dprproxy -s 32768'
				
cat >>$tmpctrl/postinst << EOF 
	if [ -f /etc/dprproxy/mod_log.conf ]; then
		rm /etc/dprproxy/mod_log.conf
	fi
	if [ -f /etc/dprproxy/proxy.conf ]; then
		rm /etc/dprproxy/proxy.conf
	fi

EOF

				cp $bindir/dprproxy/bin/dprproxy $tmpbin
				cp $bindir/dprproxy/etc/dprproxy/* $tmpcfg

				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}

	build_logsrv()
	{
		case $1 in
			bootstrap)
				./bootstrap.sh
				;;
			opkg)
				local curpwd=`pwd`
				local tmpsrc="logsrv git `get_git_ver`"
				local tmpname=$tmpdir/opkg/logsrv
				local tmpbin=$tmpname/bin
				local tmpctrl=$tmpname/CONTROL
				local tmpcfg=$tmpname/etc/logsrv
				local tmpsrv=$tmpname/etc/init.d
				mkdir -p $tmpbin
				mkdir -p $tmpctrl
				mkdir -p $tmpcfg
				mkdir -p $tmpsrv


				#提取版本号
				build_opkg_control "$tmpctrl/control" \
				"logsrv" \
				"`./get-version.sh all src/dpr_log_srv.h LOGSRV`-`date +%y%m%d%H%M`" \
				"misc" \
				"optional" \
				"$buildarch" \
				"Dinstar Log Server" \
				"$tmpsrc" \
				"libapr libexpat libaprutil libmxml libpbc libzmq libczmq libdsys libdpr"

				#准备安装脚本
				build_opkg_script $tmpctrl 	$tmpsrv logsrv 95 18 '-d \/etc\/logsrv -s 32768'
				#保留原来的配置脚本
cat >>$tmpctrl/preinst << EOF 
mkdir -p /tmp/prov/etc
if [ -d /etc/logsrv ]; then
	cp -r /etc/logsrv /tmp/prov/etc
fi
EOF


cat >>$tmpctrl/postinst << EOF 
if [ -d /etc/logsrv ]; then
	cp -r /tmp/prov/etc /etc/logsrv
fi
rm -rf /tmp/prov/etc

EOF

				cp $bindir/logsrv/bin/logsrv $tmpbin
				cp $bindir/logsrv/etc/logsrv/* $tmpcfg

				build_opkg_package $tmpname $curpwd
				;;
			*)
				build_general "$@"
				;;
		esac
	}

	#子目录处理函数，根据不同的子目录，调用合适的函数，传入合适的参数
	build_sub()
	{
		local action=$1
		local sub=$2
		case $sub in
			lib-zmq)
				echo "------>enter dir $sourcedir/third-party/$sub"
				cd $sourcedir/third-party/$sub
				build_${sub#*lib-} $action "$common_conf --prefix=$libdir --with-poller=epoll" "$common_cflags" "$common_ldflags"
				cd ../../..
				echo "<------leave dir $sourcedir/third-party/$sub"
				;;
			lib-czmq)
				echo "------>enter dir $sourcedir/third-party/$sub"
				cd $sourcedir/third-party/$sub
				build_${sub#*lib-} $action "$common_conf --prefix=$libdir --without-libsodium" "$common_cflags" "$common_ldflags"
				cd ../../..
				echo "<------leave dir $sourcedir/third-party/$sub"
				;;
			lib-minixml)
				echo "------>enter dir $sourcedir/third-party/$sub"
				cd $sourcedir/third-party/$sub
				build_${sub#*lib-} $action "$common_conf --prefix=$libdir --disable-threads --enable-shared" "$common_cflags" "$common_ldflags"
				cd ../../..
				echo "<------leave dir $sourcedir/third-party/$sub"
				;;
			lib-apr)
				echo "------>enter dir $sourcedir/third-party/$sub"
				cd $sourcedir/third-party/$sub
				build_${sub#*lib-} $action "$common_conf --prefix=$libdir --enable-threads --enable-nonportable-atomics" "$common_cflags" "$common_ldflags"
				cd ../../..
				echo "<------leave dir $sourcedir/third-party/$sub"
				;;
			lib-aprutil)
				echo "------>enter dir sourcedir/third-party/$sub"
				cd $sourcedir/third-party/$sub
				build_${sub#*lib-} $action "$common_conf --prefix=$libdir --without-sqlite2 --without-sqlite3 --with-apr=$libdir --with-expat=$libdir" "$common_cflags" "$common_ldflags"
				cd ../../..
				echo "<------leave dir $sourcedir/third-party/$sub"
				;;
			lib-curl)
				echo "------>enter dir $sourcedir/third-party/$sub"
				cd $sourcedir/third-party/$sub
				build_${sub#*lib-} $action "$common_conf --prefix=$libdir --without-winidn" "$common_cflags" "$common_ldflags"
				cd ../../..
				echo "<------leave dir $sourcedir/third-party/$sub"
				;;
			lib-sqlite)
				echo "------>enter dir $sourcedir/third-party/$sub"
				cd $sourcedir/third-party/$sub
				build_${sub#*lib-} $action "$common_conf --prefix=$libdir --enable-threadsafe" "$common_cflags" "$common_ldflags"
				cd ../../..
				echo "<------leave dir $sourcedir/third-party/$sub"
				;;
			lib-speex)
				echo "------>enter dir $sourcedir/third-party/$sub"
				cd $sourcedir/third-party/$sub
				build_${sub#*lib-} $action "$common_conf --prefix=$libdir --disable-oggtest --disable-float-api --enable-fixed-point" "$common_cflags" "$common_ldflags"
				cd ../../..
				echo "<------leave dir $sourcedir/third-party/$sub"
				;;
			lib-openssl)
				echo "------>enter dir $sourcedir/third-party/$sub"
				#cd $sourcedir/third-party/$sub
				build_${sub#*lib-} $action "$common_conf --prefix=$libdir shared"
				#cd ../../..
				echo "<------leave dir $sourcedir/third-party/$sub"
				;;
			lua-bind)
				echo "------>enter dir $sourcedir/$sub"
				cd $sourcedir/$sub
				build_bind $action "$common_conf --prefix=$libdir" "$common_cflags" "$common_ldflags"
				cd ../../..
				echo "<------leave dir $sourcedir/$sub"
				;;
			cli)
				echo "------>enter dir $sourcedir/$sub"
				cd $sourcedir/$sub
				build_${sub} $action "$common_conf --prefix=$bindir/$sub --with-lua=yes " "$common_cflags  -I$libdir/include/apr-1 -I$libdir/include/curl -I$libdir/include/dpr" "$common_ldflags"
				cd ../..
				echo "<------leave dir $sourcedir/$sub"
				;;
			provision)
				echo "------>enter dir $sourcedir/$sub"
				cd $sourcedir/$sub
				build_${sub} $action "$common_conf --prefix=$bindir/$sub" "$common_cflags" "$common_ldflags"
				cd ../..
				echo "<------leave dir $sourcedir/$sub"
				;;
			rpcproxy)
				echo "------>enter dir $sourcedir/$sub"
				cd $sourcedir/$sub
				build_${sub} $action "$common_conf --prefix=$bindir/dprproxy" "$common_cflags" "$common_ldflags"
				cd ../..
				echo "<------leave dir $sourcedir/$sub"
				;;
			logsrv)
				echo "------>enter dir $sourcedir/$sub"
				cd $sourcedir/$sub
				build_${sub} $action "$common_conf --prefix=$bindir/$sub" "$common_cflags" "$common_ldflags"
				cd ../..
				echo "<------leave dir $sourcedir/$sub"
				;;
			freeswitch)
				echo "------>enter dir $sourcedir/$sub"
				local param=$3
				cd $sourcedir/$sub
				build_${sub} $action $param "$common_conf --prefix=$bindir/$sub --disable-srtp --disable-visibility --disable-tcl --with-random=/dev/urandom --disable-parallel-build-v8 --disable-debug --enable-optimization" "$common_cflags" "$common_ldflags" "$common_cxxflags"
				cd ../..
				echo "<------leave dir $sourcedir/$sub"
				;;
			lua-web)
				echo "------>enter dir $sourcedir/$sub"
				cd $sourcedir/$sub
				build_lua_web $action
				cd ../..
				echo "<------leave dir $sourcedir/$sub"
				;;
			vpn)
				echo "------>enter dir $sourcedir/$sub"
				cd $sourcedir/$sub
				build_vpn $action
				cd ../..
				echo "<------leave dir $sourcedir/$sub"
				;;
			cloud)
				echo "------>enter dir $clouddir"
				cd $clouddir
				build_${sub} $action "$common_conf --prefix=$bindir/$sub" "$common_cflags" "$common_ldflags"
				cd ../..
				echo "<------leave dir $clouddir"
				;;
			tr069)
				echo "------>enter dir $tr069dir"
				cd $tr069dir
				echo $tr069dir
				build_${sub} $action "$common_conf --prefix=$bindir/$sub" "$common_cflags" "$common_ldflags"
				cd ../..
				echo "<------leave dir $tr069dir"
				;;
			sounds)
				echo "------>enter dir $soundsdir"
				cd $soundsdir
				build_sounds $action
				cd ../..
				echo "<------leave dir $soundsdir"
				;;
			dsp)
				echo "------>enter dir $dspdir"
				cd $dspdir
				build_dsp $action
				cd ../..
				echo "<------leave dir $dspdir"
				;;
			factorytest-client)
				echo "------>enter dir $sourcedir/$sub"
				cd $sourcedir/factorytest-client
				build_factorytest_client $action
				cd ../..
				echo "<------leave dir $sourcedir/$sub"
				;;
			*)
				#lib默认没有其他特殊参数的，都在这里处理,必须是lib-xx格式名字
				echo "------>enter dir $sourcedir/third-party/$sub"
				cd $sourcedir/third-party/$sub
				build_${sub#*lib-} $action "$common_conf --prefix=$libdir" "$common_cflags" "$common_ldflags"
				cd ../../..
				echo "<------leave dir $sourcedir/third-party/$sub"
				;;
		esac
	}
	
	build_ld()
	{
		local curdir=`pwd`
		local ldtype=$1
		local pdt=$2
		local ver=$3
		local rely=$4
		local param=""
		local app=${pdt}_${ver}_${lang}

		if [ ! -z ${brand} ]; then
			if [ "dinstar" == "${brand}" -a "1." == ${version:0:2} ]; then
				brand="unknown"
			fi
			brand="`echo ${brand} | tr '/' '_'`"
			app=${pdt}_${brand}_${ver}_${lang}
		fi
		
		cd ${packagedir}
		rm -rf ${app}.tar.gz
		rm -rf ${app}.ld
		tar -czf ../${app}.tar.gz *
		cd ..
		
		param="-s ${app}.tar.gz -d ${app}.ld -p ${pdt} -v ${ver} -t ${ldtype}"
		
		if [ $# -gt 3 ];then
			param="${param} -r ${rely}"
		fi
		
		./makeld ${param}
		
		mv ${app}.tar.gz ${packagedir}
		mv ${app}.ld ${packagedir}
		if [ -d ${packagedir}_${app} ] ; then
			rm -rf ${packagedir}_${app}
		fi
		mv ${packagedir} ${packagedir}_${app}
		
		cd $curdir
	}

	usage()
	{
		echo "$0 --cpu=[cpu] --action=[action]"
		echo "    option cpu   :arm x86 mipsel"
		echo "    option action:buildall"
		echo "                  buildlibs"
		echo "                      --list=[lib1 lib2]"
		echo "                  buildapp"
		echo "                      --list=[lib1 lib2]"
		echo "                  buildfsmod"
		echo "                      --list=[lib1 lib2]"
		echo "                  configure"
		echo "                      --list=[lib1 lib2]"
		echo "                  build"
		echo "                      --list=[lib1 lib2]"
		echo "                  buildlist"
		echo "                      --list=[lib1 lib2]"
		echo "                  clean"
		echo "                      --list=[lib1 lib2]"
		echo "                  gitclean"
		echo "                      --list=[lib1 lib2]"
		echo "                  bootstrap"
		echo "                      --list=[lib1 lib2]"
		echo "                  opkg"
		echo "                      --list=[lib1 lib2]"
		echo "                      --lang=en cn (only for lua-web,default=en,optional)"
		echo "                      --brand=[brand_name] (only for lua-web,default is empty,optional)"
		echo "                  package:"
		echo "                      --product=product"
		echo "                      --version=version"
		echo "                      --rely=version (optional)"
		echo "    option:"
		echo "        --quiet (default=no)"
		echo "        --without-syslib (default=no)"
		echo "        --help"
		echo "        --nostrip (default=yes)"
		echo "        --gdb (default=no)"
		echo "        --noconfigure"

        exit 1
	}

    ARGS=`getopt -a -o a:c:p:v:r:l:hwq -l cpu:,action:,product:,version:,rely:,list:,lang:,brand:,without-syslib,quiet,help,nostrip,gdb,noconfigure -- "$@"`
    
	[ $? -ne 0 ] && usage
	eval set -- "${ARGS}" 

	action=""
	cpu=""
	product=""
	version=""
	with_syslib="yes"
	lang="en"
	brand="dinstar"
	rely=""
	mod_list=""
	quiet=""
	mod_list=""
	gdb="-O2"
	stripflag="yes"
	configureflag="yes"
 
	while true  
	do
		case "$1" in 
        "-a" | "--action" )
			action="$2"
			shift
			;;
		"-c" | "--cpu" )
			cpu="$2"
			shift
			;;
		"-w" | "--without-syslib" )
			with_syslib="no"
			;;
		"-p" | "--product" )
			product="$2"
			shift
			;;
		"-v" | "--version" )
			version="$2"
			shift
			;;
		"-r" | "--rely" )
			rely="$2"
			shift
			;;
		"--lang" )
			lang="$2"
			shift
			;;
		"--brand" )
			brand="$2"
			shift
			;;
		"-h" | "--help" )
			usage
			;;
		"-l" | "--list" )
			mod_list="$2"
			shift
			;;
		"-q" | "--quiet" )
			quiet="--quiet"
			;;
		"--nostrip" )
			stripflag="no"
			;;
		"--gdb" )
			gdb=" -g -ggdb -O0 "
			;;
		"--noconfigure" )
			configureflag="no"
			;;
		"--" )  
            shift  
            break 
            ;;  
        esac  
	shift  
	done

	if [ -z ${cpu} ] ; then
		echo "need cpu param"
		usage
	fi

	if [ -z ${action} ]; then
		echo "need action param"
		usage
	fi

	if [[ ! -z ${brand} ]] && [[ ! -d "source/lua-web/oem_database/"${brand} ]] ; then
		echo -e "\ncan not find brand[${brand}] directory in oem database !\n"
		usage
	fi

	#全局的一些控制参数
    basedir=`pwd`
    tmpdir=/tmp/`cat /proc/sys/kernel/random/uuid`
	libdir=$basedir/libs/${cpu}
	bindir=$basedir/bin/${cpu}
	prebindir=$basedir/prebuild_bin/${cpu}
	packagedir=$basedir/package/${cpu}
	syslibdir=$basedir/sys-lib/${cpu}
	sourcedir=$basedir/source
	soundsdir=$basedir/sounds
	dspdir=$basedir/dsp
	clouddir=$basedir/source/cloud
	tr069dir=$basedir/source/tr069
	confdir=$basedir/config/${cpu}
	controldir=$basedir/package
	controlfile=$controldir/control
	servicefile=$basedir/package/service
	opkgbuild=$basedir/package/opkg-build.sh
	firmware_upgrading_temp_dir="/tmp/firmware_upgrading_temp"
	opkglist=
	
	#编译列表，该列表一定要按照被依赖的优先编译原则排列
    buildlibs="lib-zmq lib-czmq lib-pbc lib-minixml lib-apr lib-aprutil lib-dpr lua-bind lib-edit"
	#buildlibs="lib-openssl"
	#buildapps="lua-web rpcproxy provision freeswitch cli sounds dsp"
	buildapps="lua-web freeswitch"

    
	if [ ! -d $libdir ] ; then
		mkdir -p $libdir
	fi

	if [ ! -d $bindir ] ; then
		mkdir -p $bindir
	fi

	if [ ! -d $packagedir ] ; then
		mkdir -p $packagedir
	fi

   #按照cpu类型来进行编译
   case ${cpu} in
        arm)
            buildarch=c300evm
            export STAGING_DIR=/opt/OpenWrt-SDK-c300v2evm-for-Linux-i686-gcc-4.5.4_uClibc-0.9.33.2/staging_dir
			export STAGING_USR=$STAGING_DIR/target-arm_v4t_uClibc-0.9.33.2_eabi/usr
            export CCPREFIX=$STAGING_DIR/toolchain-arm_v4t_gcc-4.5.4_uClibc-0.9.33.2_eabi
            export config_TARGET_CC=$CCPREFIX/bin/arm-openwrt-linux-gcc
            export config_BUILD_CC="gcc"
            export CC_FOR_BUILD_CC="arm-openwrt-linux-gcc";
			export CC_FOR_BUILD=$CCPREFIX/bin/arm-openwrt-linux-gcc
            export CC=$CCPREFIX/bin/arm-openwrt-linux-gcc
            export CXX=$CCPREFIX/bin/arm-openwrt-linux-g++
            export LD=$CCPREFIX/bin/arm-openwrt-linux-ld
            export CPP=$CCPREFIX/bin/arm-openwrt-linux-cpp
            export AR=$CCPREFIX/bin/arm-openwrt-linux-ar
            export STRIP=$CCPREFIX/bin/arm-openwrt-linux-strip
            export RANLIB=$CCPREFIX/bin/arm-openwrt-linux-ranlib
			

			#编译相关的库和程序需要的环境变量
            export apr_cv_tcp_nodelay_with_cork=no
            export apr_cv_process_shared_works=no
            export ac_cv_func_setpgrp_void=no
            export ac_cv_file__dev_zero=yes

            export ac_cv_file__dev_ptmx=yes
            export ac_cv_file__dev_urandom=yes
            export ac_cv_file_dbd_apr_dbd_mysql_c=no
            export ac_cv_va_copy=yes
            export ac_cv_sizeof_ssize_t=4
            export ac_cv_func_malloc_0_nonnull=yes
			export ac_cv_func_realloc_0_nonnull=yes
            #必须设置,arm下不设置,apr会挂掉
            export apr_cv_mutex_recursive=yes
            export ac_cv_func_pthread_rwlock_init=yes
            export apr_cv_type_rwlock_t=yes
            export ac_cv_func_pthread_yield=yes
			
			if [ ${with_syslib} = "yes" ]; then
				libdir=$STAGING_USR
			fi

			export PATH=$libdir:$libdir/bin:$syslibdir/bin:$PATH
			export PKG_CONFIG_PATH=$libdir/lib/pkgconfig
			echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH, libdir=$libdir"
			export ARCH=armv4
			export VAPI_FLAGS=-DPRODUCT_UC2000
			export pbc_dest_dir=$libdir
			

			#公共的configure参数
            common_conf="--target=arm-openwrt-linux --host=arm-openwrt-linux-gnueabi --build=i686-pc-linux-gnu --enable-ipv6"

			#公共的cflags参数
			common_cflags="${gdb} -msoft-float -fasynchronous-unwind-tables -rdynamic -I$syslibdir/include/dpr -I$libdir/include -I$libdir/include/apr-1 -I$libdir/include/curl -I$libdir/include/dpr -DPRODUCT_UC2000"
			common_cppflags="-DPRODUCT_UC2000"

			#公共的ldflags参数
			common_ldflags="-L$syslibdir/lib -L$libdir/lib"

            ;;
        mipsel)
			
			buildarch=mipsel
            export STAGING_DIR=/home/samba/openwrt-uc100/staging_dir
			export STAGING_USR=$STAGING_DIR/target-mipsel_24kec+dsp_uClibc-0.9.33.2/usr
			export STAGING_SYS=$STAGING_DIR/toolchain-mipsel_24kec+dsp_gcc-4.8-linaro_uClibc-0.9.33.2
            export CCPREFIX=$STAGING_DIR/toolchain-mipsel_24kec+dsp_gcc-4.8-linaro_uClibc-0.9.33.2
            export config_TARGET_CC=$CCPREFIX/bin/mipsel-openwrt-linux-gcc
            export config_BUILD_CC="gcc"
            export CC_FOR_BUILD_CC="mipsel-openwrt-linux-gcc";
            export CC=$CCPREFIX/bin/mipsel-openwrt-linux-gcc
            export CXX=$CCPREFIX/bin/mipsel-openwrt-linux-g++
            export LD=$CCPREFIX/bin/mipsel-openwrt-linux-ld
            export CPP=$CCPREFIX/bin/mipsel-openwrt-linux-cpp
            export AR=$CCPREFIX/bin/mipsel-openwrt-linux-ar
            export STRIP=$CCPREFIX/bin/mipsel-openwrt-linux-strip
            export RANLIB=$CCPREFIX/bin/mipsel-openwrt-linux-ranlib
			

			#编译相关的库和程序需要的环境变量
            export apr_cv_tcp_nodelay_with_cork=no
            export apr_cv_process_shared_works=no
            export ac_cv_func_setpgrp_void=no
            export ac_cv_file__dev_zero=yes

            export ac_cv_file__dev_ptmx=yes
            export ac_cv_file__dev_urandom=yes
            export ac_cv_file_dbd_apr_dbd_mysql_c=no
            export ac_cv_va_copy=yes
            export ac_cv_sizeof_ssize_t=4
            export ac_cv_func_malloc_0_nonnull=yes
			export ac_cv_func_realloc_0_nonnull=yes
            #必须设置,arm下不设置,apr会挂掉
            export apr_cv_mutex_recursive=yes
            export ac_cv_func_pthread_rwlock_init=yes
            export apr_cv_type_rwlock_t=yes
            export ac_cv_func_pthread_yield=yes
			
			if [ ${with_syslib} = "yes" ]; then
				libdir=$STAGING_USR
			fi
			
			export PKG_CONFIG_PATH=$libdir/lib/pkgconfig
			export PATH=$STAGING_SYS:$STAGING_SYS/bin:$libdir:$libdir/bin:$syslibdir/bin:$PATH
			echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH, libdir=$libdir"
			export ARCH=mips
			export VAPI_FLAGS=-DPRODUCT_UC100
			export pbc_dest_dir=$libdir
			

			
			#公共的configure参数
            common_conf="--target=mipsel-openwrt-linux --host=mipsel-openwrt-linux --build=i686-pc-linux-gnu --enable-ipv6"

			#公共的cflags参数
			common_cflags="${gdb} -rdynamic -I$syslibdir/include/dpr -I$STAGING_SYS/include  -I$libdir/include -I$libdir/include/apr-1 -I$libdir/include/curl -I$libdir/include/dpr -DPRODUCT_UC100"
			common_cxxflags="-I$syslibdir/include/dpr -I$STAGING_SYS/include -I$libdir/include -I$libdir/include/apr-1 -I$libdir/include/curl -I$libdir/include/dpr -DPRODUCT_UC100"

			#公共的ldflags参数
			common_ldflags="-L$syslibdir/lib -L$libdir/lib"

            ;;
        x86)
            buildarch=x86

            export CC=gcc
            export ac_cv_sizeof_long_long=8

			export ac_cv_func_malloc_0_nonnull=yes
			export ac_cv_func_realloc_0_nonnull=yes
			
			if [ ${with_syslib} = "yes" ]; then
				libdir=/usr/local
			fi

			export PATH=$libdir:$libdir/bin:$syslibdir/bin:$PATH
			export PKG_CONFIG_PATH=$libdir/lib/pkgconfig
			echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH"
			export pbc_dest_dir=$libdir
			

			common_conf=

			common_cflags="-g -ggdb -I$syslibdir/include/dpr -I$libdir/include -I$libdir/include/apr-1 -I$libdir/include/curl -I$libdir/include/dpr -I/usr/include/lua5.1/"
			common_ldflags="-L$syslibdir/lib -L$libdir/lib -L/usr/lib"

            ;;
        *)
			echo "unknown cpu type"
            usage
    esac

	case ${action} in
		
		buildlibs)
			rm -rf $packagedir/*
			if [ -n "${mod_list}" ]; then
				buildlist="${mod_list}"
			else
				buildlist="$buildlibs"
			fi

			for subdir in $buildlist ; do
				#配置
				build_sub configure $subdir
				#编译
				build_sub build $subdir
				#安装
				build_sub install $subdir
				#生成安装文件
				build_sub opkg $subdir
			done
			cp $basedir/package/install.sh $packagedir
			;;
		bootstraplibs)
			if [ -n "${mod_list}" ]; then
				buildlist="${mod_list}"
			else
				buildlist="$buildlibs"
			fi

			for subdir in $buildlist ; do
				#配置
				build_sub bootstrap $subdir
			done
			;;
		buildapp )
			rm -rf $packagedir/*
			if [ -n "${mod_list}" ]; then
				buildlist="${mod_list}"
			else
				buildlist="$buildapps"
			fi
			for subdir in $buildlist ; do
				if [ "freeswitch" == ${subdir} ]; then
					cp $sourcedir/freeswitch/modules.conf.in $sourcedir/freeswitch/modules.conf
				fi
				#配置
				build_sub configure $subdir
				#编译
				build_sub build $subdir
				#安装
				build_sub install $subdir
				#生成安装文件
				build_sub opkg $subdir
			done
			cp $basedir/package/install.sh $packagedir
			;;
		buildfsmod )
			rm -rf $packagedir/*
			if [ -n "${mod_list}" ]; then
				buildlist="${mod_list}"
			fi
			echo "" > $sourcedir/freeswitch/modules.conf
			for submod in $buildlist ; do
				echo $submod >> $sourcedir/freeswitch/modules.conf
			done
			#配置
			if [ "no" != ${configureflag} ]; then
				build_sub configure freeswitch
			fi
			
		    #编译
			if [ -n "${mod_list}" ]; then
				build_sub build freeswitch modules
			else
			    build_sub build freeswitch 
			fi
			
			;;
		buildall)
			rm -rf $packagedir/*
			if [ -n "${mod_list}" ]; then
				buildlist="${mod_list}"
			else
				buildlist="$buildlibs $buildapps"
			fi
			for subdir in $buildlist ; do
				if [ "freeswitch" == ${subdir} ]; then
					cp $sourcedir/freeswitch/modules.conf.in $sourcedir/freeswitch/modules.conf
				fi
				#配置
				build_sub configure $subdir
				#编译
				build_sub build $subdir
				#安装
				build_sub install $subdir
				#生成安装文件
				build_sub opkg $subdir
			done
			cp $basedir/package/install.sh $packagedir
			;;
		buildlist)
			rm -rf $packagedir/*
			for subdir in ${mod_list} ; do
				if [ "freeswitch" == ${subdir} ]; then
					cp $sourcedir/freeswitch/modules.conf.in $sourcedir/freeswitch/modules.conf
				fi
				#配置
				build_sub configure $subdir
				#编译
				build_sub build $subdir
				#安装
				build_sub install $subdir
				#生成安装文件
				build_sub opkg $subdir
			done
			cp $basedir/package/install.sh $packagedir
			;;
		rebuild)
			rm -rf $packagedir/*
			if [ -n "${mod_list}" ]; then
				buildlist="${mod_list}"
			else
				buildlist="$buildapps"
			fi
            for subdir in $buildlist ; do
                #编译
                build_sub build $subdir
                #安装
                build_sub install $subdir
                #生成安装文件
                build_sub opkg $subdir
            done
            cp $basedir/package/install.sh $packagedir
            ;;
        package)
			if [ -z ${product} -o -z ${version} ] ; then
				echo "need product or version value"
				usage
			fi
        	build_ld "firmware" ${product} ${version} ${rely}
        	;;
		*)
			rm -rf $packagedir/*
			if [ -n "${mod_list}" ]; then
				buildlist="${mod_list}"
			else
				buildlist="$buildapps"
			fi
			for subdir in $buildlist ; do
				build_sub ${action} $subdir
			done
			cp $basedir/package/install.sh $packagedir
			rm $tmpdir -rf
	esac
