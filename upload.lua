require("lfs");
function explode (_str,seperator)
    local pos, arr = 0, {}
        for st, sp in function() return string.find( _str, seperator, pos, true ) end do
            table.insert( arr, string.sub( _str, pos, st-1 ) )
            pos = sp + 1
        end
    table.insert( arr, string.sub( _str, pos ) )
    return arr
end
function scanDir (directory)
    local i, t, popen = 0, {}, io.popen
    for filename in popen('ls "'..directory..'"'):lines() do
        i = i + 1
        t[i] = filename
    end
    return t
end
function string.escape(s) 
    return (s:gsub("[%(%)%[%]%^%$%?%*%-]","%%%0"))
end
function os.exists(path)
    local fh = io.open(path,"r")
    if fh ~= nil then
        local ok, err, code = fh:read("*a")
        fh:close()
        if code ~= 21 then
            return false
        end
        return true
    else
        return false
    end
end
function os.mkdir(path)
    if not os.exists(path) then
        return lfs.mkdir(path)
    end
    return true
end
local function createFileFromChunks (chunk_dir,upload_dir,resumableFilename,resumableChunkSize,resumableTotalSize)
    local chunks = scanDir(chunk_dir)
    local total = 0
    for k,v in pairs(chunks) do
        if string.find(v,string.escape(resumableFilename)) ~= nil then
            total = total + 1
        end
    end
    ngx.log(ngx.DEBUG,"total:"..total.."chunkSize:"..resumableChunkSize.."totalSize:",resumableTotalSize)
    if total and total * resumableChunkSize >= (resumableTotalSize - resumableChunkSize + 1) then
        local filename_table = explode(resumableFilename,".")
        local file_extension = table.remove(filename_table)
        local time = os.time()
        local date = os.date("%Y%m%d",time)
        local file_dir = upload_dir .. date .. "/"
        if not os.exists(file_dir) then
            os.mkdir(file_dir)
        end
        local file_name = ngx.md5(time .. resumableFilename) .. "." .. file_extension
        local file,err = io.open(file_dir .. file_name, "a+")
        if err == nil then
            local i = 1 
            while (i <= total) do
                local part_file = io.open(chunk_dir .. resumableFilename .. ".part" .. i, "r")
                if part_file ~= nil then
                    local part_content = part_file:read("*a")
                    part_file.close()
                    file:write(part_content)
                    os.remove(chunk_dir .. resumableFilename .. ".part" .. i)
                end
                i = i + 1
            end
            file:close()
            os.remove(chunk_dir)
            lfs.chmod(file_dir .. file_name, 640)
            ngx.say('{"file":"'.. date .. "/" ..file_name..'"}')
        else
            ngx.log(ngx.DEBUG,"fail to open destination file.")
        end
    end
end
local upload_dir = "/yourpath/media/"
local temp_dir = "/yourpath/temp/"
local request_method = ngx.var.request_method
if request_method == "GET" then
    local args = ngx.req.get_uri_args()
    local resumableIdentifier = ""
    local resumableFilename = ""
    local resumableChunkNumber = ""
    for key, val in pairs(args) do
        if key == "resumableIdentifier" then
            resumableIdentifier = val
        elseif key == "resumableFilename" then
            resumableFilename = val
        elseif key == "resumableChunkNumber" then
            resumableChunkNumber = val
        end
    end
    local chunk_file = temp_dir .. resumableIdentifier .. "/" .. resumableFilename .. ".part" .. resumableChunkNumber
    local f = io.open(chunk_file,"r")
    if f~=nil then 
        io.close(f)
        ngx.exit(ngx.HTTP_OK)
    else
        ngx.exit(ngx.HTTP_NOT_FOUND)
    end
    
elseif request_method == "POST" then
    receive_headers = ngx.req.get_headers()  
    local boundary = "--" .. string.sub(receive_headers["Content-Type"],31)
    ngx.req.read_body()
    body_file = ngx.req.get_body_file()
    f, e = io.open(body_file,"rb")
    if e == nil then
        body_data = f:read("*all")
        f:close()
        local body_data_table = explode(tostring(body_data),boundary)
        table.remove(body_data_table,1)
        table.remove(body_data_table)
        local resumableIdentifier = ""
        local resumableFilename = ""
        local resumableChunkNumber = ""
        local resumableTotalSize = "" 
        local resumableChunkSize = "" 
        local fileData = nil
        for i,v in ipairs(body_data_table) do
            local start_pos,end_pos,capture1,capture2 = string.find(v,'Content%-Disposition: form%-data; name="(.+)"; filename="(.*)"')
            if not start_pos then
                local t = explode(v,"\r\n\r\n")
                local param_name = string.sub(t[1],41,-2)
                local param_value = table.concat(t,"\r\n\r\n",2):sub(1,-3)
                if param_name == "resumableIdentifier" then
                    resumableIdentifier = param_value
                elseif param_name == "resumableFilename" then
                    resumableFilename = param_value
                elseif param_name == "resumableChunkNumber" then
                    resumableChunkNumber = param_value
                elseif param_name == "resumableTotalSize" then
                    resumableTotalSize = param_value
                elseif param_name == "resumableChunkSize" then
                    resumableChunkSize = param_value
                end
            else
                local t = explode(v,"\r\n\r\n")
                local param_value = table.concat(t,"\r\n\r\n",2):sub(1,-3)
                fileData = param_value
            end
        end
        local chunk_dir = temp_dir .. resumableIdentifier .. "/"
        local chunk_file =  chunk_dir .. resumableFilename .. ".part" .. resumableChunkNumber
        if not os.exists(chunk_dir) then
            os.mkdir(chunk_dir)
        end
        if fileData ~= nil then
            local file, err = io.open(chunk_file, "w+")
            if err == nil then
                file:write(fileData)
                createFileFromChunks(chunk_dir,upload_dir,resumableFilename,resumableChunkSize,resumableTotalSize)
                file:close()
            else
                ngx.say(err)
            end     
        end   
    end
end

