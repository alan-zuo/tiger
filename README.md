# Tiger

### 定位

Tiger是一个基于Openresty开发的实时统计计算工具。

日常开发中，我们经常会遇到需要实时统计数据的场景，实现的可选工具有很多，比如Storm、Spark streaming、Kafka streams等。但实际上在大多数普通业务系统中，实时计算的模型都是类似的，即Key组合多Value的累加计算。比如，在广告系统中，需要实时统计不同广告位不同地域的请求量和曝光量，以此作为广告投放的决策依据之一，这里所谓的“key组合”为广告位和地域，“多value”为请求量和曝光量。如果用上述相对复杂的流式计算框架完成类似任务，学习成本、运维成本、开发成本都较高，有点像杀鸡用牛刀。

Tiger设计实现了这个简单的计算模型，一般使用中无需编写任何计算代码，只需按照Tiger特定的数据格式向Tiger写入数据，实时累加的数据就会落入指定位置。

### 优势

* 零编程需要即可搭建一个实时流计算；
* 类似Flume支持多种Source和Sink，且易扩展；
* 得益于简单计算模型的固化，计算性能、实时性、资源占用率都表现非常好；
* 支持数据自定义处理插件，可通过lua对数据做中间转换；

### 安装

1. 下载Tiger
2. 从Openresty官网下载其安装包
3. ./install [Openresty安装包] [目标目录] [端口]
4. 根据需要修改配置文件conf/config.lua
5. 启动./start.sh

### 支持的Source和Sink

#### Source

* Redis Source
* Http Sink

#### Sink

* MySQL Source
* Http Sink

### 配置

安装后conf/config.lua为配置文件，此文件中包含了所有Tiger的配置，所有的配置项均在此文件中。

配置文件为一个lua文件，Tiger为了简洁，通过这种方式将配置融入框架lua代码中，所以不要修改配置文件中return关键字及大括号结构。配置分为两块，Source配置和Sink配置，区分的方法很简单，名称为source开头的即为source配置，sink同理。

Http Source是默认开启的，虽然开启，但如果不用的话，不会额外占用系统资源。

|配置名称|含义|是否为必填|
|:-:|:-:|:-:|
|source_redis_on|是否开启Redis Source，true为开启，false为关闭|是|
|source_redis|Redis配置列表，每行包含ip、port、list_name|否|
|source_tps_on|是否打开tps统计的开关，true为开启，false为关闭|是|
|sink_type|Sink的类型，mysql为开启MySQL Sink，http为开启Http Sink，空或其它值为不开启任何Sink|是|
|sink_http_target_ip|Http Sink的ip|sink_type为http时必填|
|sink_http_target_port|Http Sink的port|sink_type为http时必填|
|sink_http_timeout|Http Sink的超时时间|sink_type为http时必填|
|sink_http_pool_timeout|Http Sink的连接池中连接的过期时间|sink_type为http时必填|
|sink_http_pool_size|Http Sink的连接池大小|sink_type为http时必填|
|sink_mysql_host|MySQL Sink的host|sink_type为mysql时必填|
|sink_mysql_port|MySQL Sink的port|sink_type为mysql时必填|
|sink_mysql_dbname|MySQL Sink的数据库名|sink_type为mysql时必填|
|sink_mysql_username|MySQL Sink的用户名|sink_type为mysql时必填|
|sink_mysql_passwd|MySQL Sink的密码|sink_type为mysql时必填|
|sink_mysql_timeout|MySQL Sink的超时时间|sink_type为mysql时必填|
|sink_mysql_pool_size|MySQL Sink的连接池大小|sink_type为mysql时必填|
|sink_mysql_conn_ttl|MySQL Sink的连接池中连接的过期时间|sink_type为mysql时必填|
|sink_interval|多久向下传递一次数据|是|

### Tps统计

通过配置项source_tps_on开启tps统计，tps信息会在error.log中不断的打印，供分析Tiger运行情况用。注意，这里的tps并不是source直观上的读入数据的条数，因为Tiger支持用分号分割一次写入多条数据，这个tps是拆分成多条后的数据条数，也就是标准Tiger数据格式的条数。这样做的理由是，Tiger基于单条Tiger数据来做内部累加计算，这个tps才能直观的反应Tiger的压力，而不是Source读入的条数。

### 连接两个Tiger

两个Tiger间的通信使用Http Sink，在上一个配置文件中配置下一个Tiger的ip、port等即可形成一个两个节点的计算流。

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
