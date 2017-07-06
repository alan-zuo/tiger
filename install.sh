#
# Tiger的安装脚本
#

# 执行此脚本前需要确保如下依赖已经安装：
# openresty依赖：perl 5.6.1+,libreadline,libpcre,libssl

# 在执行此脚本时请先准备好openresty的tar.gz包，从官网下载即可
# 例如openresty-1.9.7.4.tar.gz

# 参数说明
# $1 openresty的tar.gz包的绝对路径，必选
# $2 安装目录，必选
# $3 端口号，必选

# 参数检查
if [[ $# != 3 ]]; then
    echo "ERROR: 参数错误"
    echo "Usage: $0 <Openresty安装包绝对路径> <安装目录> <端口号>"
    exit 1
fi

openresty_path=$1
install_dir=$2
port=$3

# 如果目标安装目录已存在，发出警告并终止脚本
if [[ -d "$install_dir" ]]; then
    echo "ERROR: 安装目录已存在，删除后再安装"
    exit 1
fi

# 获取openresty的版本号
tmpstr=${openresty_path#*openresty-}
openresty_version=${tmpstr%*.tar.gz}

# 安装Openresty
cd `dirname $0`
tar zxf $openresty_path -C .
cd openresty-${openresty_version}
./configure --prefix=$install_dir/openresty && make && make install
cd ..
rm -rf openresty-${openresty_version}

cp -r conf $install_dir
./init_conf.sh $install_dir $port

mkdir $install_dir/logs
touch $install_dir/logs/error.log

cp start.sh stop.sh restart.sh reload.sh $install_dir

cp -r lua $install_dir

echo "安装完成，请按需配置conf.lua配置后启动Tiger"
