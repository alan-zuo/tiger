local datain = require "source.datain"

local function handler()
    -- 只支持POST请求
    if ngx.var.request_method == "POST" then
        ngx.req.read_body()
        local body_data = ngx.req.get_body_data()
        if not body_data or body_data == "" then
            return
        end

        local body_table_fun = loadstring("return " .. body_data)
        local body_table = body_table_fun()
        if not body_table then
            return
        end

        for i, line in pairs(body_table) do
            datain.to_shdict(line)
        end
    end
end

return {
    handler = handler
}
