--
-- 常用功能函数
--

-- 将字符串按指定分隔符分隔，分隔的结果以table返回
-- szFullString是要分隔的字符串，szSeparator是分隔符
local function string_split(str, sep)
    local res = {}
    local sep_len = string.len(sep)
    local start_index = 1

    while true do
        local last_index = string.find(str, sep, start_index)
        if not last_index then
            local pis = string.sub(str, start_index)
            if pis ~= "" then
                table.insert(res, pis)
            end
            break
        end
        local pis = string.sub(str, start_index, last_index - 1)
        if pis ~= "" then
            table.insert(res, pis)
        end
        start_index = last_index + sep_len
    end

    return res
end

return {
    string_split = string_split
}
