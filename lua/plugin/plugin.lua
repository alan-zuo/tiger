local function source_handler(data)
    local result = {}

    -- 这里添加单条数据处理代码
    -- 根据data的内容生成新的data数组
    result[1] = data

    return result
end

local function init_worker()
    -- 这里添加初始化代码
end

return {
    init_worker = init_worker,
    source_handler = source_handler
}
