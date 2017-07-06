#
# 用于初始化nginx.conf
# 主要完成宏替换
#

# 参数说明
# $1 安装目录，必选
# $2 端口号，必选

if [[ $# != 2 ]]; then
    echo "ERROR: 参数错误"
    echo "Usage: $0 <conf目录> <端口号>"
    exit
fi

work_dir=$1
port=$2

cpu_num=`cat /proc/cpuinfo | grep processor | wc -l`
cpu_aff=''
for i in `seq $cpu_num`; do
    for j in `seq $cpu_num`; do
        if [[ $i == $j ]]; then
            cpu_aff=$cpu_aff'1'
        else
            cpu_aff=$cpu_aff'0'
        fi
    done
    if [[ $i != 8 ]]; then
        cpu_aff=$cpu_aff' '
    fi
done

sed "s:__WORKER_NUM__:$cpu_num:g" $work_dir/conf/nginx.conf.template |
sed "s:__CPU_AFF__:$cpu_aff:g" |
sed "s:__PATH__:$work_dir:g" |
sed "s:__PORT__:$port:g" > $work_dir/conf/nginx.conf
rm -rf $work_dir/conf/nginx.conf.template
