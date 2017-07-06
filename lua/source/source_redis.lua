local config = require "config"
local datain = require "source.datain"
local redis  = require "resty.redis"
local util   = require "util"
local shdict = ngx.shared.shdict

-- 读Redis list并将数据写到shared_dict
local function read_redis(premature, redis_index)
    while true and not ngx.worker.exiting() do
        -- 连接redis
        local rds = redis:new()
        local redis_ip = config.source_redis[redis_index].ip
        local redis_port = config.source_redis[redis_index].port
        local ok, err = rds:connect(redis_ip, redis_port)
        if not ok then -- 连接失败
            ngx.log(ngx.ERR, "Failed to connect redis " .. redis_ip .. ":" .. redis_port .. ",", err)
            break
        else -- 连接成功
            ngx.log(ngx.NOTICE, "Worker " .. ngx.worker.id() .. " 已连接到Redis " .. redis_ip .. ":" .. redis_port)
            while true and not ngx.worker.exiting() do
                -- lrange+ltrim的性能可能更好，但是多个Tiger实例读同一个Redis需要分布式锁，所以选择pop
                -- brpop在没有数据时会阻塞，设定最多阻塞10秒
                local res, err = rds:brpop(config.source_redis[redis_index].list, 10)
                if not res then
                    ngx.log(ngx.ERR, "Failed to execute Redis command brpop,", err)
                    break
                elseif res ~= ngx.null then
                    -- 如果是一次写入的多条数据，则拆分后写入shdict
                    local data = res[2]
                    local data_pis = util.string_split(data, ";")
                    for i, pis in pairs(data_pis) do
                        datain.to_shdict(pis)
                    end
                end
            end
            rds:close()
        end
    end

    -- 1秒后再次连接Redis，避免频繁连接
    if not ngx.worker.exiting() then
        local ok, err = ngx.timer.at(1, read_redis, redis_index)
        if not ok then
            ngx.log(ngx.ERR, "Failed to create timer,", err)
        end
    end
end

local function assign_index(a, b, id)
    local result = {}
    for i = 1, math.max(a,b) do
        if (i-1)%b == id then
            result[#result+1] = (i-1)%a+1
        end
    end
    return result
end

local function init_worker()
    -- 根据redis数、worker数、worker_id得出本worker需要连接的redis下标列表
    local redis_num = #config.source_redis
    local worker_num = ngx.worker.count()
    local worker_id = ngx.worker.id()
    local redis_index_array = assign_index(redis_num, worker_num, worker_id)

    for i, redis_index in ipairs(redis_index_array) do
        -- 用timer的方式启动读redis的线程
        if not ngx.worker.exiting() then
            local ok, err = ngx.timer.at(0, read_redis, redis_index)
            if not ok then
                ngx.log(ngx.ERR, "Failed to create timer", err)
            end
        end
    end
end

return {
    init_worker = init_worker
}
