#
# Tiger的停止脚本
#

cd `dirname $0`
work_dir=`pwd`

kill `cat $work_dir/openresty/nginx/logs/nginx.pid`
if [ $? == 0 ]; then
    echo "Tiger 已停止"
else
    echo "Tiger 停止失败"
    exit 1
fi
