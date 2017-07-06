local config     = require "config"
local util       = require "util"
local sink_http  = require "sink.sink_http"
local sink_mysql = require "sink.sink_mysql"

local shdict = ngx.shared.shdict

-- 定时器回调函数
-- 完成一次从share dict取一批数据并调用特定sink的过程
local function sink(premature)
    -- 记录时间戳，以便后续计算本次sink消耗时间
    local sink_start_time = ngx.now()

    local take_lock_value = 0

    -- 减少hold计数器的值并判断是否需要hold
    if shdict:incr("hold_count", -1) < 0 then
        take_lock_value = shdict:incr("take_lock", 1)
    end

    -- 尝试抢占take锁
    if take_lock_value == 1 then -- 抢到了
        -- 判断当前应该从哪个队列取数
        local use_shdict
        local data_tag = shdict:get("data_tag")
        if data_tag == "a" then
            use_shdict = ngx.shared.shdictb
        else
            use_shdict = ngx.shared.shdicta
        end

        -- 取数
        local keys = use_shdict:get_keys(2000)
        if #keys == 0 then -- 取不到数据，说明队列是空的
            -- 轮换标记位
            if data_tag == "a" then
                shdict:set("data_tag", "b")
            else
                shdict:set("data_tag", "a")
            end

            -- 将hold计数器设置为worker数
            -- 以此方式通知其他worker数下一次sink需要hold
            shdict:set("hold_count", ngx.worker.count())

            -- 释放take锁
            shdict:set("take_lock", 0)
        else -- 取到数据
            local data_sink_table = {}
            for i, shkey in pairs(keys) do
                local t1 = util.string_split(shkey, "|")
                local table_name = t1[1]
                if not data_sink_table[table_name] then
                    data_sink_table[table_name] = {}
                end

                local key_str = t1[2]
                if not data_sink_table[table_name][key_str] then
                    data_sink_table[table_name][key_str] = {}
                end

                local val_str = t1[3]
                local val = use_shdict:get(shkey)
                if val then
                    data_sink_table[table_name][key_str][val_str] = val
                end

                use_shdict:delete(shkey) -- 删除这条key
            end

            -- 释放take锁
            shdict:set("take_lock", 0)

            -- 根据sink_type配置，调用不同的sink
            if config.sink_type == "http" then
                sink_http.sink(data_sink_table)
            elseif config.sink_type == "mysql" then
                sink_mysql.sink(data_sink_table)
            end
        end
    end

    -- 计算时间差
    local sink_time_spent = ngx.now() - sink_start_time

    -- 计算下次delay的时间
    local delay = 0.001 * config.sink_interval - sink_time_spent
    if delay < 0.0 then
        delay = 0.0
        ngx.log(ngx.WARN, "sink无法在配置的interval时间（" .. config.sink_interval .. "ms）内完成，数据有堆积风险")
    end

    -- 通过timer实现interval
    if not ngx.worker.exiting() then
        local ok, err = ngx.timer.at(delay, sink)
        if not ok then
            ngx.log(ngx.ERR, "Failed to create timer: " .. err)
        end
    end
end

local function init()
    -- 设置take锁
    shdict:set("take_lock", 0)

    -- 设置hold计数器
    shdict:set("hold_count", ngx.worker.count())

    -- 修正sink interval，低于100ms按100ms生效
    if config.sink_interval < 100 then
        config.sink_interval = 100
    end
end

local function init_worker()
    -- 启动定时任务
    if not ngx.worker.exiting() then
        local ok, err = ngx.timer.at(0.001*config.sink_interval, sink)
        if not ok then
            ngx.log(ngx.ERR, "Failed to create timer: " .. err)
        end
    end
end

return {
    init = init,
    init_worker = init_worker,
}
