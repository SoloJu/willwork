#!/bin/bash
#
# 解压tgz文件
# 备份中间库
# 启动过一次平台系统再停止
# 




# OEM文件目录
cur_dir=$(pwd)

para=$1

# OEM文档启动参数产品安装路径
new_path=$2
old_path=$3

mdb_string='mongodb://root:2khyEdVt@192.168.0.202:21330,192.168.0.201:21331,192.168.0.203:21332/tapdata?replicaSet=asiainfo&authSource=admin'


# 停旧平台
stop_old() {
    echo '-------- Stop old platform --------'
    ${old_path}/tapdata stop -f
}
# 备份中间库
bak_mdb() {
	echo '-------- Backing up middle MDB --------'
    mongodump --uri ${mdb_string} --gzip -o /opt/midDB_bak-$(date +"%Y%m%d")/
}


# 1. 复制图标

mod_icon() {
    echo '-------- Copy icons to destination --------'
    
    cp -f ${cur_dir}/img/favicon* ${new_path}/components/tapdata-management/client/static/icon/
    cp -f ${cur_dir}/img/logo.png ${new_path}/components/tapdata-management/client/static/icon/
    cp -f ${cur_dir}/img/logo.5f34f75.png ${new_path}/components/tapdata-management/client/static/img/
}
# 2. 修改index.html 文件
mod_html() {
    echo '-------- Modify the index.html --------'
    sed -i 's/Tapdata/Data Platform/g' ${new_path}/components/tapdata-management/client/index.html
}
# 3. 修改api文件
mod_api() {
    echo '-------- Modify the api js/ts doc --------'
    sed -i 's/Tapdata OpenAPI/Data Platform/g' ${new_path}/components/apiserver/src/application.ts
    sed -i 's/Find out more about Tapdata.//g' ${new_path}/components/apiserver/src/application.ts
    sed -i 's/https:\/\/tapdata.io//g' ${new_path}/components/apiserver/src/application.ts    

    sed -i 's/Tapdata OpenAPI/Data Platform/g' ${new_path}/components/apiserver/dist/src/application.js
    sed -i 's/Find out more about Tapdata.//g' ${new_path}/components/apiserver/dist/src/application.js
    sed -i 's/https:\/\/tapdata.io//g' ${new_path}/components/apiserver/dist/src/application.js
}
# 4. 修改中间库设置
mod_mdb() {
    echo '-------- Modify the middle MDB frontend settings --------'
    mongo ${mdb_string} ./oem_asia_modify.js
}


echo "New platform path: ${new_path}"
echo "Old platform path: ${old_path}"
echo "Do operation: ${para}"
echo "OEM path: ${cur_dir}"

read -p 'Above information is OK? (Y/N)' YN

if [ "${YN}" = "Y" ]; then

    case ${para} in
    	no)
    		echo 'Please type parameter after command!'
    		;;
    	stop_old)
    		stop_old
    		;;	
    	bak_mdb)
    		bak_mdb
    		;;
    	mod_icon)
    		mod_icon
    		;;
    	mod_html)
    		mod_html
    		;;
    	mod_api)
    		mod_api
    		;;
    	mod_mdb)
    		mod_mdb
    		;;
    	mod_all)
            mod_icon
            mod_html
            mod_api
            mod_mdb
    		;;
    	*)
            echo 'Nothing to do'
            ;;
    esac
else 
	echo 'Nothing to do and exit'
	exit
fi

exit