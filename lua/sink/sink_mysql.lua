local config = require "config"
local util   = require "util"
local mysql  = require "resty.mysql"

-- 本地表索引
local tbindex = {}

-- 是否已初始化
local inited = false

function exesql(sql)
    -- 创建mysql连接
    local mydb, err = mysql:new()
    if not mydb then
        ngx.log(ngx.ERR, "Failed to init Mysql: " .. err)
    else
        -- 设置mysql超时时间
        mydb:set_timeout(config.sink_mysql_timeout)
        -- 连接mysql
        local ok, err = mydb:connect {
            host     = config.sink_mysql_host,
            port     = config.sink_mysql_port,
            database = config.sink_mysql_dbname,
            user     = config.sink_mysql_username,
            password = config.sink_mysql_passwd
        }
        if ok then -- 连接成功
            -- 执行sql
            local res, err = mydb:query(sql)
            if not res then
                ngx.log(ngx.ERR, "Failed to excute sql: " .. sql .. ", " .. err)
            end
            while err == "again" do
                res, err = mydb:read_result()
            end

            -- 将连接加到连接池
            local ok, err = mydb:set_keepalive(config.sink_mysql_conn_ttl, config.sink_mysql_pool_size)
            if not ok then
                ngx.log(ngx.ERR, "Failed to keep mysql connection: " .. err)
            end

            return res
        else
            ngx.log(ngx.ERR, "Failed to connect mysql: " .. err)
            return nil
        end
    end
end

-- 如果数据表表不存在，则通过复制表结构创建它
local function touch_table(tbname, index)
    local tbname_index = tbname .. "_" .. index -- 数据表名

    -- 查询是否存在此数据表
    local res = exesql("show tables like '" .. tbname_index .. "'")
    if not res then return false -- 查询失败
    elseif #res == 0 then -- 不存在
        -- 创建它
        local res = exesql("create table " .. tbname_index .. " like " .. tbname)
        if res then return true -- 创建成功
        else return false end -- 创建失败
    else return true end -- 存在
end

-- 执行insert sql语句
local function insert_mysql(sql)
    exesql(sql)
end

-- 获取单个table的sql列表
local function get_sqllist(tbname, tbdata)
    local sqllist = {}

    for key_str, val_tb in pairs(tbdata) do
        local sql_p1 = "insert into " .. tbname
        local sql_p2 = " ("
        local sql_p3 = " values ("
        local sql_p4 = " ON DUPLICATE KEY UPDATE "

        local format_error = false

        -- 拆解key串
        local keyin = ""
        local kt1 = util.string_split(key_str, ",")
        for i=1, #kt1 do
            local kt2 = util.string_split(kt1[i], "=")
            if #kt2 ~= 2 then
                format_error = true
                break
            end
            if kt2[1] == tbindex[tbname]["key"] then -- 发现索引
                keyin = kt2[2]
            end
            sql_p2 = sql_p2 .. kt2[1] .. ","
            sql_p3 = sql_p3 .. "'" .. kt2[2] .. "',"
        end

        -- 根据索引列的值生成索引
        if next(tbindex[tbname]) then -- 如果此表设置了索引
            local index = string.sub(keyin, tbindex[tbname]["head"], tbindex[tbname]["tail"])
            touch_table(tbname, index)
            sql_p1 = sql_p1 .. "_" .. index
        end

        -- 遍历val表
        for val_k, val_v in pairs(val_tb) do
            sql_p2 = sql_p2 .. val_k .. ","
            sql_p3 = sql_p3 .. val_v .. ","
            sql_p4 = sql_p4 .. val_k .. "=" .. val_k .. "+" .. val_v .. ","
        end

        sql_p2 = string.sub(sql_p2, 1, string.len(sql_p2)-1) .. ") "
        sql_p3 = string.sub(sql_p3, 1, string.len(sql_p3)-1) .. ") "
        sql_p4 = string.sub(sql_p4, 1, string.len(sql_p4)-1)

        if format_error then
            ngx.log(ngx.ERR, "Data format error: key_str = " .. key_str)
        else
            sqllist[#sqllist+1] = sql_p1 .. sql_p2 .. sql_p3 .. sql_p4
        end
    end

    return sqllist
end

-- 解析key和索引
local function parse_key_index(key_str)
    local h = string.find(key_str, "<")
    if not h then return {} end

    local key = string.sub(key_str, 1, h-1)

    local str_in = string.sub(key_str, h+1, string.len(key_str)-1)
    local tb = util.string_split(str_in, "-")
    if #tb ~= 2 then return {} end

    local key_index = {}
    key_index["key"] = key
    key_index["head"] = tonumber(tb[1])
    key_index["tail"] = tonumber(tb[2])

    return key_index, key
end

local function init()
    -- 检查是否存在tbindex表，无则创建
    local res = exesql("show tables like 'tbindex'")
    if not res then return false
    elseif #res == 0 then
        local res = exesql("create table tbindex (name char(64) primary key, idx char(64))")
        if not res then return false end
    end

    -- 读取tbindex到本地
    local res = exesql("select * from tbindex")
    if not res then return false
    else
        for i=1, #res do
            tbindex[res[i].name] = parse_key_index(res[i].idx)
        end
    end

    return true
end

-- 创建表
local function create_table(tbname, tbdata)
    for key_str, val_tb in pairs(tbdata) do
        local sql_p1 = "create table " .. tbname .. " ("
        local sql_p2 = "primary key("

        local key_index = {}
        local kstr = ""

        -- 拆解key串
        local kt1 = util.string_split(key_str, ",")
        for i=1, #kt1 do
            local kt2 = util.string_split(kt1[i], "=")
            local k = kt2[1]
            if not next(key_index) then
                key_index = parse_key_index(kt2[1])
                if next(key_index) then
                    kstr = kt2[1]
                    k = key_index["key"]
                end
            end

            sql_p1 = sql_p1 .. k .. " " .. kt2[2] .. ","
            sql_p2 = sql_p2 .. k .. ","
        end

        -- 遍历val表
        for val_k, val_v in pairs(val_tb) do
            sql_p1 = sql_p1 .. val_k .. " " .. val_v .. " default 0,"
        end

        -- 拼接建表sql
        sql_p2 = string.sub(sql_p2, 1, string.len(sql_p2)-1) .. ")"
        local sql = sql_p1 .. sql_p2 .. ")"

        -- 如果已经存在此表，则删除它，达到重建的目的
        exesql("delete from tbindex where name='" .. tbname .. "'")
        exesql("drop table " .. tbname)

        -- 执行建表sql
        exesql(sql)

        -- 将索引写入索引表
        local res = exesql("insert into tbindex values ('" .. tbname .. "','" .. kstr .. "')")
        if res then
            tbindex[tbname] = key_index
        end

        break -- 只需建一次
    end
end

local function sink(sinktb)
    -- 未初始化时初始化
    if not inited then
        if init() then inited = true
        else return end
    end

    -- 遍历sinktb
    for tbname, tbdata in pairs(sinktb) do
        if string.sub(tbname, 1, 1) == "+" then -- 建表指令
            create_table(string.sub(tbname, 2, #tbname), tbdata)
        else -- 数据指令
            if tbindex[tbname] then -- 表存在才处理数据
                -- 生成此表的sql列表
                local sqllist = get_sqllist(tbname, tbdata)
                -- 执行此表的sql列表
                if sqllist then
                    for i=1, #sqllist do
                        insert_mysql(sqllist[i])
                    end
                end
            end
        end
    end
end

return {
    sink = sink
}
