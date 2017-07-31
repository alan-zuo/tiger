local util = require "util"
local plugin = require "plugin.plugin"
local shdict  = ngx.shared.shdict
local split = util.string_split
local config = require "config"

-- 解析item并累加到shared_dict
-- item格式举例：tb1|key1=v1,key2=v2|value1=num1,value2=num2
local function to_shdict_in(item)
    local item_pis = split(item, "|")
    if #item_pis ~= 3 then return end

    local values_pis = split(item_pis[3], ",")

    local use_shdict
    local data_tag = shdict:get("data_tag")
    if data_tag == "a" then
        use_shdict = ngx.shared.shdicta
    else
        use_shdict = ngx.shared.shdictb
    end

    for i, values in ipairs(values_pis) do
        local val_pis = split(values, "=")
        if #val_pis ~= 2 then return end

        local num = tonumber(val_pis[2])

        if num and num > 0 then
            local shd_key = item_pis[1] .. "|" ..  item_pis[2] .. "|" .. val_pis[1]
            local newval, err = use_shdict:incr(shd_key, num, 0)
            if not newval then
                ngx.log(ngx.ERR, "ShareDict command incr fail, " .. err)
            end
        elseif string.sub(item_pis[1], 1, 1) == "+" then
            local shd_key = item_pis[1] .. "|" ..  item_pis[2] .. "|" .. val_pis[1]
            local succ, err = use_shdict:set(shd_key, val_pis[2])
            if not succ then
                ngx.log(ngx.ERR, "ShareDict command set fail, " .. err)
            end
        end
    end
end

local function to_shdict(item)
    -- 统计source tps
    if config.source_tps_on then
        shdict:incr("source_tps", 1)
    end

    local item_array = plugin.source_handler(item)

    for i,item in ipairs(item_array) do
        to_shdict_in(item)
    end
end

return {
    to_shdict = to_shdict
}
