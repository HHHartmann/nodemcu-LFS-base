------------------------------------------------------------------------------
-- HTTP server Hello world example
--
-- LICENCE: http://opensource.org/licenses/MIT
-- Vladimir Dronnikov <dronnikov@gmail.com>
------------------------------------------------------------------------------

-- taken from marcoskirsch/nodemcu-httpserver
local function parseUri(uri)

    local function parseArgs(args)
       local r = {}; i=1
       if args == nil or args == "" then return r end
       for arg in string.gmatch(args, "([^&]+)") do
          local name, value = string.match(arg, "(.*)=(.*)")
          if name ~= nil then r[name] = value end
          i = i + 1
       end
       return r
    end

   local r = {}

   if uri == nil then return r end
   if uri == "/" then uri = "/index.html" end
   local questionMarkPos = uri:find("?")
   if questionMarkPos == nil then
      r.path = uri:sub(1, questionMarkPos)
      r.args = {}
   else
      r.path = uri:sub(1, questionMarkPos - 1)
      r.args = parseArgs(uri:sub(questionMarkPos+1, #uri))
   end
   return r
end




require("httpserver").createServer(80, function(req, res)
  -- analyse method and url
  if req.url ~= "/log" then
    print("+R", req.method, req.url, node.heap())
  end
  local uri = parseUri(req.url)
  local size
  if req.url ~= "/log" then
    print("filename:", uri.args.name)  
    print("command:", uri.path)
  end
  local tempFileName = "__temp_test_file"
  local myFile

  local SaveFile = function(self, chunk)
    print("+B", chunk and #chunk, node.heap())
    
    if not chunk then
      -- reply
      myFile:close()
      local status,err = pcall(function() node.compile(tempFileName..".lua") end)
      if status then
        file.remove(tempFileName..".lc")
        if file.exists(uri.args.name) then
          file.remove(uri.args.name)
        end
        file.rename(tempFileName..".lua", uri.args.name)
        
        res:send(nil, 200)
        res:send_header("Access-Control-Allow-Origin", "*")
        res:send_header("Connection", "close")
        res:send("Compiled and saved.")
      else
        print("error", err)
        res:send(nil, 400)
        res:send_header("Access-Control-Allow-Origin", "*")
        res:send_header("Connection", "close")
        res:send(err)
      end
      res:finish()
      return
    end
    
    myFile:write(chunk)
    size = size - #chunk
    print(size, "bytes left")
  end
  
  -- setup handler of headers, if any
  if uri.path == "/compileAndSave" then
    myFile = file.open(tempFileName..".lua", "w+")
    req.onheader = function(self, name, value)
      print("+H", name, value)
      if name == "content-length" then 
        size = tonumber(value)
        req.ondata = SaveFile
      end
    end
  elseif uri.path == "/restart" then
    res:send(nil, 201)
    res:send_header("Connection", "close")
    res:send_header("Access-Control-Allow-Origin", "*")
    res:finish()
    local f = function() print("posting restart") node.task.post(node.restart) end
    res:csend(f)
  elseif uri.path == "/log" then
    res:send(nil, 200)
    res:send_header("Connection", "close")
    res:send_header("Content-Type", "text/plain")
    res:send_header("Access-Control-Allow-Origin", "*")
    res:send(Logger.getlog())
    res:send(Logger.getlog())
    res:send(Logger.getlog())
    res:send(Logger.getlog())
    collectgarbage()
    res:finish()
  elseif uri.path == "/info" then
    res:send(nil, 200)
    res:send_header("Connection", "close")
    res:send_header("Content-Type", "text/json")
    res:send_header("Access-Control-Allow-Origin", "*")
    local info = {name = "Nelli", heap = node.heap(), id = node.chipid()}
    info = sjson.encode(info)
    res:send(info)
    res:finish()
  else
    res:send(nil, 404)
    res:send_header("Connection", "close")
    res:send("URL unknown")
    res:finish()
  end
  
  -- or just do something not waiting till body (if any) comes
  --res:finish("Hello, world!")
  --res:finish("Salut, monde!")
end)
