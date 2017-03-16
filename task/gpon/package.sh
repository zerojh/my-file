#!/bin/sh
	usage()
	{
		echo -e "\nusage:"
		echo "$0 --profile=[profile]"
		echo "    option profile: default custom    (optional)"
		echo "    option profile: custom"
		echo "                    --cpu=arm mipsel  (optional,default=mipsel)"
		echo "                    --product=product (optional,default=ubg1000)"
		echo "                    --version=version"
		echo "                    --rely=version (optional)"
		echo "                    --lang=en cn (only for lua-web,default=en,optional)"
		echo "                    --list=[app1 app2]"
		echo "    option:"
		echo "        --help"
		echo "    embedded profile:"
		echo -e "             default: --cpu=mipsel --product=ubg1000 --version='1.52.x.y 2.52.x.y' --lang='en cn' --list='freeswitch lua-web sounds dsp'\n"

        exit 1
	}

    ARGS=`getopt -a -o pf:c:pd:v:r:la:ls:h -l profile:,cpu:,product:,version:,rely:,lang:,list:,help -- "$@"`
    
	[ $? -ne 0 ] && usage
	eval set -- "${ARGS}" 
	
	profile=""
	cpu=""
	product=""
	version=""
	lang=""
	rely=""
	app_list=""

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
			if [ -z ${cpu} ] ; then
				cpu="mipsel"
			fi
			
			if [[ "mipsel" != ${cpu} ]] && [[ "arm" != ${cpu} ]]; then
				echo -e "\nerror cpu type,only support arm or mipsel"
				usage
			fi	
			if [ -z ${lang} ] ; then
				lang="en"
			fi
			if [ -z ${product} ] ; then
				product="ubg1000"
			fi
			if [ -z ${app_list} ] ; then
				app_list="freeswitch lua-web sounds cloud dsp filesystem"
			fi
			;;
		*)
			if [ -z ${lang} ] ; then
				lang="en cn"
			fi
			subver=${version#*.*.}
			version="1.52.$subver 2.52.$subver"
			
			cpu="mipsel"
			product="ubg1000"
			app_list="freeswitch lua-web sounds cloud dsp filesystem"
			#app_list="freeswitch"
	esac
	
	for sub_ver in ${version} ; do
		for sub_lang in ${lang} ; do
			echo -e "\nReady to package "$sub_ver"_"$sub_lang" ...\n"
			echo "./build.sh --cpu=$cpu --action=opkg --list='$app_list' --lang=$sub_lang"
			./build.sh --cpu=$cpu --action=opkg --list="$app_list" --lang=$sub_lang
			echo "./build.sh --cpu=$cpu --action=package --product=$product --version=$sub_ver --lang=$sub_lang"
			./build.sh --cpu=$cpu --action=package --product=$product --version=$sub_ver --lang=$sub_lang
			echo -e "\nPackage "$sub_ver"_"$sub_lang" done!\n"
		done
	done
