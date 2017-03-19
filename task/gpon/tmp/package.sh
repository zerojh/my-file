#!/bin/sh
usage()
{
	echo -e "\nusage:"
	echo "$0 --profile=[profile]"
	echo "    option profile: default custom    (optional)"
	echo "    option profile: custom"
	echo "                    --cpu=arm mipsel  (optional,default=mipsel)"
	echo "                    --product=product (optional,default=uc100)"
	echo "                    --version=version"
	echo "                    --rely=version (optional)"
	echo "                    --lang=en cn (only for lua-web,default=en,optional)"
	echo "                    --brand=[brand_name]  (only for lua-web,defaultv is empty,optional)"
	echo "                    --ldtype=firmware/patch  (usr for make brand patch,defaultv is firmware,optional)"
	echo "                    --list=[app1 app2]"
	echo "    option:"
	echo "        --help"
	echo "    embedded profile:"
	echo -e "             default: --cpu=mipsel --product=uc100 --version='1.53.x.y 2.53.x.y' --lang='en cn' --list='freeswitch tr069 sounds dsp filesystem cloud vpn factorytest-client lua-web'\n"

    exit 1
}

build_brand_patch()
{
	local curdir=`pwd`
	local rely=${version}
	local filename=${version}_patch_01_${brand}_info
	local tmpdir=/tmp/`cat /proc/sys/kernel/random/uuid`
	local tmptar=${filename}.tar.gz

	mkdir -p ${tmpdir}/1
	cp source/lua-web/oem_database/${brand}/* ${tmpdir}/1/

	cd ${tmpdir}/1
	echo "#!/bin/sh" > active
	echo "cp /usr/lib/lua/patch/1/oem /etc/config/oem" >> active
	echo "cp /usr/lib/lua/patch/1/${brand}_logo.png /www/luci-static/resources/" >> active
	echo "/etc/init.d/lucid restart" >> active
	echo "#!/bin/sh" > deactive
	#can not rollback oem patch, no more action in deactive file
	cd ..
	tar -zcf ${tmptar} 1

	cp ${tmptar} ${curdir}/package/
	cd ${curdir}/package

	version=${rely%.*}.`expr ${rely#*.*.*.} + 1`

	echo "./makeld -s ${tmptar} -d ${filename}.ld -p uc100 -v ${version} -r ${rely} -t patch"
	./makeld -s ${tmptar} -d ${filename}.ld -p uc100 -v ${version} -r ${rely} -t patch

	rm ${tmpdir} -rf
	
	cd $curdir
}

ARGS=`getopt -a -o pf:c:pd:v:r:la:ls:h -l profile:,cpu:,product:,version:,rely:,lang:,brand:,ldtype:,list:,help -- "$@"`

[ $? -ne 0 ] && usage
eval set -- "${ARGS}" 

profile=""
version=""
lang=""
rely=""
cpu="mipsel"
brand=""
product="uc100"
ldtype="firmware"
app_list="freeswitch tr069 sounds dsp filesystem cloud vpn factorytest-client lua-web"

while true  
do
	case "$1" in
	"--profile" )
		profile="$2"
		shift
		;;
	"--cpu" )
		cpu="$2"
		shift
		;;
	"--product" )
		product="$2"
		shift
		;;
	"--version" )
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
	"--ldtype" )
		ldtype="$2"
		shift
		;;
	"-h" | "--help" )
		usage
		shift
		;;
	"-l" | "--list" )
		app_list="$2"
		shift
		;;
	"--" )
        shift
        break
        ;; 
    esac
shift
done

if [ -z ${version} ] ; then
	echo -e "\nneed version value\n"
	usage
fi

case ${profile} in
	
	custom)
		if [[ "mipsel" != ${cpu} ]] && [[ "arm" != ${cpu} ]]; then
			echo -e "\nerror cpu type, only support arm or mipsel"
			usage
		fi
		if [[ ! -z ${ldtype} ]] && [[ "firmware" != ${ldtype} ]] && [[ "patch" != ${ldtype} ]]; then
			echo -e "\nerror ldtype value, only support firmware/patch\n"
			usage
		fi
		if [[ "patch" == ${ldtype} ]] && [[ -z ${brand} ]]; then
			echo -e "\npatch ldtype only use to make oem brand patch now, please input oem brand name\n"
			usage
		fi
		if [[ ! -z ${brand} ]] && [[ ! -d "source/lua-web/oem_database/"${brand} ]] ; then
			echo -e "\ncan not find brand[${brand}] directory in oem database !\n"
			usage
		fi
		if [ "bluewave" == "${brand}" ]; then
			echo -e "\n bluewave have two sub modules: WP1 / S5V , please special one, for example, bluewave/WP1"
			usage
		fi
		if [ -z ${lang} ] ; then
			lang="en"
		fi
		if [ -z ${brand} ] ; then
			brand="dinstar"
		fi
		;;
	*)
		if [ -z ${lang} ] ; then
			lang="en cn"
		fi
		subver=${version#*.*.}
		version="1.53.$subver 2.53.$subver"
		brand="dinstar"
esac

case ${ldtype} in
	firmware)
		for sub_ver in ${version} ; do
			for sub_lang in ${lang} ; do
				echo -e "\nReady to package "$sub_ver"_"$sub_lang" ...\n"
				echo "./build.sh --cpu=$cpu --action=opkg --list='$app_list' --lang=$sub_lang --brand=${brand}"
				./build.sh --cpu=$cpu --action=opkg --list="$app_list" --version=$sub_ver --lang=$sub_lang --brand=${brand}
				echo "./build.sh --cpu=$cpu --action=package --product=$product --version=$sub_ver --lang=$sub_lang --brand=${brand}"
				./build.sh --cpu=$cpu --action=package --product=$product --version=$sub_ver --lang=$sub_lang --brand=${brand}
				echo -e "\nPackage "$sub_ver"_"$sub_lang" done!\n"
			done
		done
		;;
	patch)
		build_brand_patch
		;;
	*)
		echo "\nunknown ldtype type\n"
        usage
esac