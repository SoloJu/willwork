#!/bin/bash

# 假设登录用户是root
# 没有安装Java
# 没有安装MongoDB
# /opt/pkg/目录不存在
# 
# 自动化安装目录
# ./tapd8_deploy
# ----/config
#     ----/set.env
#     ----/application.yml
#     ----/node_l.yml
#     ----/repl_init.js
# ----/pkg
# ----/tapd8_install.sh
# 
# 部署前仔细检查config目录中的各配置文件
# 
# TODO, 检查部署环境
# 用户权限
# CPU, MEM, 硬盘空量
# Java版本
# MongoDB版本
# MongoDB的数据库,日志, Tapdata的工作目录放在最大容量的挂载盘里
# 根据CPU, MEM, 硬盘容量配置MongoDB的 cacheSize, oplogSize


. config/set.env
# 自动部署文件目录
cur_dir=$(pwd)
# 自动部署文档启动参数
para=$1

if [ "${para}" = "" ]; then
	para='no'
else
	para=$1
fi

# 系统参数
sys_name=''
sys_ver=''
sys_core=0
sys_mem=0

# 检查系统环境
env_chk() {
	if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        sys_name='CentOS'
    	sys_ver=$(cat /etc/system-release | awk '{print $4}' | awk 'BEGIN{FS="."}{print $1}')
    	if [ "${sys_ver}"=='7' ]; then
    		echo "${sys_name} ${sys_ver}"
    	else
    		echo "The system is ${sys_name}, but version is not 7."
    		exit 1
    	fi
    else
    	echo "The system is not CentOS."
    	exit 1
    fi

    sys_core=$(cat /proc/cpuinfo | grep 'processor' | wc -l)
    sys_mem=$(free -m | grep Mem | awk '{print  $2}')

    if [ "${sys_core}" -ge 4 ]; then 
    	echo "CPU cores is ${sys_core} great than and  equal 4."
    else
    	echo 'CPU cores less than 4.'
    	exit 1
    fi

    if [ "${sys_mem}" -ge 7000 ]; then 
    	echo "Mem is ${sys_mem}MB."
    else
    	echo "Mem ${sys_mem}MB is not enoughß."
    	exit 1
    fi

}

# 所有安装包都放入/opt/pkg/
pre_install() {
	mkdir -p ${pkg_dir}
	echo 'Created directory /opt/pkg/'
	echo 'Copied source files to /opt/pkg/'
    cp ${cur_dir}/pkg/jdk*gz ${pkg_dir}
    jdk=$(ls ${deploy_dir}/pkg/ | grep -E '^jdk.*gz$')
    sed -i "s/^jdk=.*$/jdk='${jdk}'/g" ./config/set.env
    echo "Java file is: $(grep jdk= ./config/set.env)"
    cp ${cur_dir}/pkg/mongo*gz ${pkg_dir}
    mongo=$(ls ${deploy_dir}/pkg/ | grep -E '^mongodb.*gz$')
    sed -i "s/^mongo=.*$/mongo='${mongo}'/g" ./config/set.env
    echo "MongoDB file is: $(grep mongo= ./config/set.env)"
    cp ${cur_dir}/pkg/tapdata*gz ${pkg_dir}
    tapd8=$(ls ${deploy_dir}/pkg/ | grep -E '^tapdata.*gz$')
    sed -i "s/^tapd8=.*$/tapd8='${tapd8}'/g" ./config/set.env
    echo "Tapdata file is: $(grep tapd8= ./config/set.env)"
}


# 安装java
java_install() {
    echo 'Start to install Java'
    if [ -f ${pkg_dir}/${jdk} ]; then
    	echo "${pkg_dir}/${jdk} exists."
    	tar -zxvf ${pkg_dir}/${jdk} -C ${deploy_dir}
    	jdk_dir=$(ls -al /opt/ | grep jdk | awk '{print $9}')
        jdk_dir=${deploy_dir}/${jdk_dir}
        echo 'Java is deployed at: '${jdk_dir}
        echo "JAVA_HOME=${jdk_dir}" >> ${HOME}/.bash_profile
        echo 'CLASSPATH=${JAVA_HOME}/lib' >> ${HOME}/.bash_profile
        echo 'PATH=$PATH:${JAVA_HOME}/bin' >> ${HOME}/.bash_profile
        echo 'export PATH JAVA_HOME CLASSPATH' >> ${HOME}/.bash_profile
        source ${HOME}/.bash_profile
        java -version
        echo '+++ Java installed +++'
    else
    	echo "${pkg_dir}/${jdk} is not existed."
    	exit 1
    fi
}

mongo_install() {
    echo 'Start to install MongoDB'
    if [ -f ${pkg_dir}/${mongo} ]; then
    	echo "${pkg_dir}/${mongo} exists."
    	tar -zxvf ${pkg_dir}/${mongo} -C ${deploy_dir}
    	mongo_dir=$(ls -al /opt/ | grep mongodb | awk '{print $9}')
        mongo_dir=${deploy_dir}/${mongo_dir}
        echo 'MongoDB is deployed at: '${mongo_dir}
        echo "MONGO_HOME=${mongo_dir}" >> ${HOME}/.bash_profile
        echo 'PATH=$PATH:${MONGO_HOME}/bin' >> ${HOME}/.bash_profile
        echo 'export PATH MONGO_HOME' >> ${HOME}/.bash_profile
        source ${HOME}/.bash_profile
        mongo -version
        echo '+++ MongoDB installed +++'
    else
    	echo "${pkg_dir}/${mongo} is not existed."
    	exit 1
    fi
}

tapd8_install() {
    echo 'Start to install Tapdata'
    if [ -f ${pkg_dir}/${tapd8} ]; then
    	echo "${pkg_dir}/${tapd8} exists."
    	tar -zxvf ${pkg_dir}/${tapd8} -C ${deploy_dir}
    	tapd8_dir=$(ls -al /opt/ | grep tapdata | awk '{print $9}')
        tapd8_dir=${deploy_dir}/${tapd8_dir}
        echo 'Tapdata is deployed at: '${tapd8_dir}
        echo '+++ Tapdata installed +++'
    else
    	echo "${pkg_dir}/${tapd8} is not existed."
    	exit 1
    fi
}

# 主节点启动
mdb_p_init() {
    echo 'Start to launch MongoDB instance'
    mkdir -p ${deploy_dir}/${mongo_work_dir}/{config,db,log}
    mkdir -p ${deploy_dir}/${mongo_work_dir}/db/node_l
    cp ${cur_dir}/config/node_l.yml ${deploy_dir}/${mongo_work_dir}/config
    cp ${cur_dir}/config/repl_init.js ${deploy_dir}/${mongo_work_dir}/config
    # 修改yml文件的默认参数
    sed -i "s/rs_name/${rs_name}/g" ${deploy_dir}/${mongo_work_dir}/config/node_l.yml
    sed -i "s/oplogSizeMB_default/${oplogSizeMB_default}/g" ${deploy_dir}/${mongo_work_dir}/config/node_l.yml
    sed -i "s/cacheSizeGB_default/${cacheSizeGB_default}/g" ${deploy_dir}/${mongo_work_dir}/config/node_l.yml
    sed -i "s/port_default/${port_default}/g" ${deploy_dir}/${mongo_work_dir}/config/node_l.yml
    sed -i "s/pass_default/${pass_default}/g" ${deploy_dir}/${mongo_work_dir}/config/repl_init.js
    openssl rand -base64 741 > ${deploy_dir}/${mongo_work_dir}/config/${rs_name}.key
    chmod 400 ${deploy_dir}/${mongo_work_dir}/config/${rs_name}.key
    source ${HOME}/.bash_profile

    cat ${deploy_dir}/${mongo_work_dir}/config/node_l.yml

    read -p 'That yml file is ready?(Y/N): ' YN
    if [ "${YN}" = "Y" ]; then

        mongod -f ${deploy_dir}/${mongo_work_dir}/config/node_l.yml    

        i=1
        mdb_completed=0
        while [ ${i} -le 3 ]
        do
            if [ $(ps -ef | grep 'mongod -f' | wc -l)==2 ]; then
                echo '+++ MongoDB instance established +++'
                mdb_completed=1
                i=4
            else
                sleep 10s
                let "i++"
                echo 'MongoDB instance is creating...'
            fi
        done
        
        if [ ${mdb_completed} -eq 1 ]; then
            mongo --port $(cat "${deploy_dir}/${mongo_work_dir}/config/node_l.yml" | grep port | awk '{print $2}') ${deploy_dir}/${mongo_work_dir}/config/repl_init.js
            if [ $? == 0 ]; then 
                echo '+++ MongoDB init complished +++'
            fi
        else
            echo 'MongoDB is not created, please check'
            exit 1
        fi
    else
        echo 'Please check again.'
    fi
}

# 从节点启动，在不同的服务器上,主节点启动后才能动
mdb_s_init() {
    echo 'Start to launch MongoDB instance'
    mkdir -p ${deploy_dir}/${mongo_work_dir}/{config,db,log}
    mkdir -p ${deploy_dir}/${mongo_work_dir}/db/node_l
    echo 'Copy from primary node files'
    read -p 'Please type primary node IP: ' p_ip
    read -p 'Please type primary node Port(default 22): ' p_port
    if [ "${p_port}" = "" ]; then
        p_port=22
    fi
    scp -P ${p_port} root@${p_ip}:${deploy_dir}/${mongo_work_dir}/config/* ${deploy_dir}/${mongo_work_dir}/config
    ls -al ${deploy_dir}/${mongo_work_dir}/config
    cat ${deploy_dir}/${mongo_work_dir}/config/node_l.yml

    read -p 'That yml file is ready?(Y/N): ' YN
    if [ "${YN}" = "Y" ]; then
        mongod -f ${deploy_dir}/${mongo_work_dir}/config/node_l.yml
        j=1
        mdb_s_completed=0
        while [ ${j} -le 3 ]
        do
            if [ $(ps -ef | grep 'mongod -f' | wc -l)==2 ]; then
                echo '+++ MongoDB instance established +++'
                mdb_s_completed=1
                j=4
            else
                sleep 10s
                let "j++"
                echo 'MongoDB instance is creating...'
            fi
        done
    else
        echo 'Please check again.'
    fi
    
}

tapd8_p_init() {
	# Tapdata安装目录
    tapd8_dir=$(ls -al /opt/ | grep tapdata-v | awk '{print $9}')
    tapd8_dir=${deploy_dir}/${tapd8_dir}
    mkdir -p ${tapd8_work_dir}
    echo -n "${tapd8_work_dir}" > ${tapd8_dir}/.workDir
    cp ${cur_dir}/config/application.yml ${tapd8_work_dir}
    # 因为hostname -I取值后面有个空格，所以要加awk把空格去掉
    # host_ip=$(hostname -I | awk '{print $1}')
    
    read -p "Please enter the MongoDB ReplicaSet IP, Separated by commas: " mongo_3ip
    ip1=$(echo ${mongo_3ip} | cut -d ',' -f 1)
    ip2=$(echo ${mongo_3ip} | cut -d ',' -f 2)
    ip3=$(echo ${mongo_3ip} | cut -d ',' -f 3)

    if [ "${ip1}" != "" ]; then
        mongo_uri=${ip1}:${port_default}
    fi
    if [ "${ip2}" != "" ]; then
        mongo_uri=${mongo_uri},${ip2}:${port_default}
    fi
    if [ "${ip3}" != "" ]; then
        mongo_uri=${mongo_uri},${ip3}:${port_default}
    fi
    sed -i "s/mdb_string/${mongo_uri}\/tapdata\?replicatSet=tapd8/g" ${tapd8_work_dir}/application.yml
    # sed -i "s/mdb_string/${host_ip}:${port_default}\/tapdata\?replicatSet=tapd8/g" ${tapd8_work_dir}/application.yml
    grep 'mongoConnectionString' ${tapd8_work_dir}/application.yml

    read -p 'Is that mongoConnectionString OK?(Y/N): ' YN
    if [ "${YN}" = "Y" ]; then
        read -p "Please enter the Tapdata frontend IP: " frontend_ip
        sed -i "s/tapdata_url_string/http:\/\/${frontend_ip}:3030\/api\//g" ${tapd8_work_dir}/application.yml
        cd ${tapd8_dir}
        ./tapdata start
        echo '+++ Tapdata deployed +++'
    else
        echo 'Please check again.'
    fi
}

tapd8_s_init() {
    # Tapdata安装目录
    tapd8_dir=$(ls -al /opt/ | grep tapdata-v | awk '{print $9}')
    tapd8_dir=${deploy_dir}/${tapd8_dir}
    mkdir -p ${tapd8_work_dir}
    echo -n "${tapd8_work_dir}" > ${tapd8_dir}/.workDir
    read -p "Please enter the Tapdata frontend IP: " frontend_ip
    read -p 'Please enter frontend node Port(default 22): ' p_port
    if [ "${p_port}" = "" ]; then
        p_port=22
    fi
    scp -P ${p_port} root@${frontend_ip}:${tapd8_work_dir}/application.yml ${tapd8_work_dir}
    sed -i 's/uuid:.*$//g' ${tapd8_work_dir}/application.yml
    cat ${tapd8_work_dir}/application.yml

    read -p 'Is that application.yml OK?(Y/N): ' YN
    if [ "${YN}" = "Y" ]; then
        cd ${tapd8_dir}
        ./tapdata start agent
        echo '+++ Tapdata deployed +++'
    else
        echo 'Please check again.'
    fi
}

case ${para} in
	no)
		echo 'Please type parameter after command!'
		;;
	env)
		env_chk
		;;
	pre)
		pre_install
		;;
	java)
		java_install
		;;
	mongo)
		mongo_install
		;;
	tapd8)
		tapd8_install
		;;
	mdb_p_init)
		mdb_p_init
		;;
    mdb_s_init)
        mdb_s_init
        ;;    
	tapd8_p_init)
		tapd8_p_init
		;;
    tapd8_s_init)
        tapd8_s_init
        ;;    
	*)
        echo 'Nothing to do'
        ;;
esac

exit
