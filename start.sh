#
# Tiger的启动脚本
#

cd `dirname $0`
work_dir=`pwd`

$work_dir/openresty/nginx/sbin/nginx -c $work_dir/conf/nginx.conf
if [[ "$?" == "0" ]]; then
    echo "Tiger 启动成功"
else
    echo "Tiger 启动失败"
    exit 1
fi
