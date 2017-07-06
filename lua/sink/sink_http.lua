local config = require "config"
local http = require "lua-resty-http.resty.http"

local function sink(data_sink_table)
    local data = "{"

    for table_name, table_data in pairs(data_sink_table) do
        for key_str, val_tb in pairs(table_data) do
            local item = table_name .. "|" .. key_str .. "|"

            for val_k, val_v in pairs(val_tb) do
                item = item .. val_k .. "=" .. val_v .. ","
            end
            item = string.sub(item, 1, #item-1)
            data = data .. "'" .. item .. "',"
        end
    end

    if data ~= "{" then
        data = string.sub(data, 1, #data-1) .. "}"

        local httpc = http.new()
        httpc:set_timeout(config.sink_http_timeout)
        httpc:connect(config.sink_http_target_ip, config.sink_http_target_port)

        local res, err = httpc:request({
            path = "/data",
            method = "POST",
            body = data
        })

        if not res then
            ngx.log(ngx.ERR, "Sink http: failed to request: " .. err)
            return
        end

        res:read_body()

        local ok, err = httpc:set_keepalive(config.sink_http_pool_timeout, config.sink_http_pool_size)

        if not ok then
            ngx.log(ngx.ERR, "Sink http: failed to keepalive: " .. err)
            return
        end
    end
end

return {
    sink = sink
}
