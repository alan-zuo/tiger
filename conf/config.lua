--
-- Tiger的配置
--

return {

-- 数据源，可取http和redis，可同时开启
-- http默认开启且无法关闭
-- redis默认关闭，开启需要配置source_redis_on

-- 是否开启Redis数据源
source_redis_on = false,
-- Redis配置
source_redis = {
    { ip = "127.0.0.1", port = 4001, list = "tiger" },
    { ip = "127.0.0.1", port = 4002, list = "tiger" }
},

-- 是否开启source tps统计
source_tps_on = false,

---------------------------------------------

-- 数据输出，可取mysql和http
-- 如果不配置此参数或配置错误，Tiger会自动销毁外发数据
sink_type = "",

-- http数据输出目标
sink_http_target_ip = "127.0.0.1",
sink_http_target_port = 3002,
sink_http_timeout = 500, -- ms
sink_http_pool_timeout = 60000, -- ms
sink_http_pool_size = 32,

-- mysql数据输出端口
sink_mysql_host       = "127.0.0.1",
sink_mysql_port       = 3306,
sink_mysql_dbname     = "tiger",
sink_mysql_username   = "root",
sink_mysql_passwd     = "root",
sink_mysql_timeout    = 60000, --ms
sink_mysql_pool_size  = 32,
sink_mysql_conn_ttl   = 60000, --ms

-- 每个sink进程的操作interval
sink_interval   = 1000 -- ms，最低100ms，低于100ms会按100ms生效

}
