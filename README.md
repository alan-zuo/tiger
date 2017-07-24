# Tiger

**编辑中...**

Tiger是一个基于Openresty开发的实时统计计算工具。

日常开发中，我们会遇到很多需要实时统计数据的场景，实现的可选工具很多，比如Storm、Spark streaming、Kafka streams等。
但是实际上在大多数业务系统中，计算的模型都是类似的，即Key组合多Value的累加计算。
比如在广告系统中，需要实时统计分广告位分地域的请求量和曝光量来对广告投放提供决策依据，key为广告位和地域，value为请求量和曝光量。
如果用上述相对复杂的框架完成类似任务，学习成本、运维成本、开发成本都较高，有点杀鸡用牛刀。

Tiger设计实现了这个简单的Key组合多Value的累加计算模型，无需编写任何计算代码，只需要向Tiger写入特定格式数据，它就会自动将数据做好计算后落入指定位置。

关键功能：
1. 类似Flume的多Source多Sink模型，固定支持Redis/Http Source、MySQL/Http Sink；
2. 得益与计算模型的固化和多线程生产配多线程消费的设计，计算效率、实时性、资源占用率都表现非常好；
3. 依赖Lua语言的简便和Openresty框架的优势，可快速编写自定义Source和Sink；
4. 每一个Tiger实例都可以是一个实时计算网的节点，可像积木一样组合成任意的计算流；
5. 支持数据自定义处理插件，比如对数据中的某个字段做MD5加密等转换操作；

安装步骤：
1. 下载Tiger
2. 从Openresty官网下载其安装包
3. ./install [Openresty安装包] [目标目录] [端口]
4. 根据需要修改配置文件conf/config.lua
5. 启动./start.sh

默认开启Http Source，不开启任何Sink

配置详解：

安装后conf/config.lua为配置文件，此文件中包含了所有Tiger的配置，不存在不在此文件中的配置项
配置文件为一个lua文件，Tiger为了简便，通过这种方式将配置融入Lua代码中，所以不要修改配置文件中return关键字及大括号结构
配置分为两块，Source配置和Sink配置，区分的方法很简单，名称为source开头的即为source配置，sink同理
Http Source是默认开启的，对然开启，但不用的话，也不会占用任何系统资源

Redis Source通过source_redis_on开关来开启，true为开启，false为关闭
source_redis配置项是一个lua table，默认的配置文件中已经给了例子，直观很好理解
可配置多个redis，每个redis可配置ip、端口、list名称
source_tps_on为是否打开tps统计的开关，tps的大小会在error.log中不断的打印，供分析Tiger运行情况用
注意，这里的tps并不是source直观上的读入数据的条数，因为Tiger支持用分号分割一次写入多条数据，这个tps是拆分成多条后的数据条数
也就是标准Tiger数据格式的条数，这样做的理由是，Tiger基于单条Tiger数据来做内部累加计算，这个tps才能直观的反应Tiger的压力，而不是Source读入的条数
不过，有时候Source读数据的系统资源占用同样高，未来会扩展source读入的tps

sink_type是sink的类型，如果为空，则不开启任何sink
如果配置mysql，则开启Mysql sink，如果配置http，则开启http sink
如果配置的非mysql也非http，则等同于设置空，不开启任何sink
sink_http开头的为http sink的配置，sink_mysql为mysql sink的配置
http sink的设定是为了建立tiger之间的连接，那么这个http sink则配置的是下游tiger的信息
包括ip、端口、http超时、连接池大小和超时
mysql的配置包含ip、端口、数据库名称、用户名、密码、超时时间、连接池大小和超时

sink_interval是多久向下游写一次数据
Tiger的计算框架是source不断接收数据累加在本地内存中，每隔一段时间将累加的数据写向下游，这个interval就是配置这个的

多Redis和多worker之间的匹配：

如果阅读了关于redis的配置，你会知道，Tiger的redis source支持配置多个redis
那么多个worke和多个redis是如何匹配对应的呢？
如果每个worker都连接所有redis，则会建立大量redis连接，这是比较臃肿的设计
我们通过几个例子来理解Tiger的做法
比如启动了8个worker，配置了8个redis，则Tiger会让每个worker分别连接一个redis，正好每个worker一个
如果是8 worker + 1 redis，则每个worker都会连接这个redis，因为要负载均衡，不能有worker闲着
如果是8 worker + 3 redis，则像填空一样，8个worker是8个格子，依次填入redis，设redis为1 2 3编号，则结果为1 2 3 1 2 3 1 2
如果是8 worker + 9 redis，则有一个worker会多连一个redis
到这里你应该理解了Tiger的做法，就是类似上述按顺序填空，不能让任何一个worker闲着，也不能让任何一个redis不被连接
