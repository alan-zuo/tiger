# Tiger

Tiger是一个基于Openresty开发的实时统计计算工具。

日常开发中，我们会遇到很多需要实时统计数据的场景，实现的可选很多，比如Storm、Spark streaming、Kafka streams等。
但是实际上在大多数业务系统中，计算的模型都是一样的，即Key组合多Value的累加计算。
比如在广告系统中，需要实时统计分广告位分地域的请求量和曝光量来对广告投放提供决策依据。
如果用上述庞大的框架完成，学习成本、运维成本、开发成本都比较高，有点像杀鸡用牛刀。

Tiger设计实现了这个简单的Key组合多Value的累加计算模型，无需编写任何计算代码，只需要向Tiger写入特定格式数据，它就会自动将数据做好计算后落入指定位置。

关键优势：
1. 类似Flume的多Source多Sink模型，固定支持Redis source、Http source、MySQL sink、Http sink；
2. 得益与计算模型的固化和多线程生产配多线程消费的设计，计算效率、实时性、资源占用率都表现非常好；
3. 依赖Lua语言的简便和Openresty框架的优势，可快速编写自定义Source和Sink；
4. 每一个Tiger实例都是一个实时计算网的节点，可像积木一样组合成任意的计算流；
5. 支持数据自定义处理插件，比如对数据中的某个字段做MD5加密等转换操作；

安装步骤：
1. 下载Tiger
2. 从Openresty官网下载其安装包
3. ./install [Openresty安装包] [目标目录] [端口]
4. 根据需要修改配置文件conf/config.lua
5. 启动./start.sh

默认开启Http Source，不开启任何Sink

配置详解：

TODO
