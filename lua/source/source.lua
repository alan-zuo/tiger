local config = require "config"
local source_redis = require "source.source_redis"
local shdict  = ngx.shared.shdict

-- 在 Nginx init 阶段会被调用
local function init()
    if config.source_tps_on then
        shdict:set("source_tps", 0)
        shdict:set("source_tps_lock", 0)
    end
end

-- 统计并打印source tps
local function cal_tps(premature)
    local tps = shdict:get("source_tps")
    shdict:set("source_tps", 0)
    ngx.log(ngx.NOTICE, "tps = " .. tps)

    if not ngx.worker.exiting() then
        local ok, err = ngx.timer.at(1, cal_tps)
        if not ok then
            ngx.log(ngx.ERR, "Failed to create timer: " .. err)
        end
    end
end

-- 在 Nginx init_worker 阶段会被调用
local function init_worker()
    if config.source_redis_on then
        source_redis.init_worker()
    end

    -- 以抢占的方式启动唯一的一个统计和打印tps的线程
    if shdict:incr("source_tps_lock", 1) == 1 then
        if not ngx.worker.exiting() then
            local ok, err = ngx.timer.at(1, cal_tps)
            if not ok then
                ngx.log(ngx.ERR, "Failed to create timer: " .. err)
            end
        end
    end
end

return {
    init = init,
    init_worker = init_worker
}
