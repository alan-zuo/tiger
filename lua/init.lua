--
-- 负责Tiger在Nginx init和init_worker两个阶段的初始化
--

local source = require "source.source"
local sink = require "sink.sink"
local plugin = require "plugin.plugin"

-- 在Nginx的init阶段会被调用
local function init()
    -- 设置数据标号
    -- Tiger使用两个share dict作为KV累加存储，编号为a和b
    -- 保持写入和读取分别在a和b来保证读写不冲突
    local shdict = ngx.shared.shdict
    shdict:set("data_tag", "a")

    -- 调用source的初始化
    source.init()

    -- 调用sink的初始化
    sink.init()
end

-- 在Nginx的init_worker阶段会被调用
local function init_worker()
    -- 调用source的worker初始化
    source.init_worker()

    -- 调用sink的worker初始化
    sink.init_worker()

    -- 调用plugin的worker初始化
    plugin.init_worker()
end

return {
    init = init,
    init_worker = init_worker,
}
