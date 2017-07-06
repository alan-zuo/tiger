#
# Tiger的重启脚本
# 注意停止和启动中间有强制3秒的等待
#

./stop.sh
sleep 3
./start.sh
