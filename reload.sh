#
# Tiger的reload脚本
#

cd `dirname $0`
work_dir=`pwd`

$work_dir/openresty/nginx/sbin/nginx -s reload
if [ $? == 0 ]; then
    echo "Tiger reload 成功"
else
    echo "ERROR: Tiger reload 失败"
fi
