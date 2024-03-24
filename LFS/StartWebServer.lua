-----------------------------------------------------------------------------------------------------
-- WebServer module
--
-- LICENCE: WebServer://opensource.org/licenses/MIT
-- Gregor Hartmann https://github.com/HHHartmann
------------------------------------------------------------------------------
local tonumber = tonumber


local WebServer = require("WebServer")







  local function normalize(req, res, Next, params)
  --  if req.url:gmatch(".*&") 
  end

--use(normalize)




local function redirectHostToIp(req, res, Next, params)
  if req.headers and req.headers["host"] == params.hostname then
    print("detected hostname. Will send redirect in next version")
  end
  return Next()
end

WebServer.use(redirectHostToIp, {hostname = "nodemcu"})




WebServer.route("/info", function(req, res)
    res:send(nil, 200)
    res:send_header("Connection", "close")
    res:send_header("Content-Type", "text/json")
    res:send_header("Access-Control-Allow-Origin", "*")
    local lfsTimestamp = node.LFS.Timestamp and node.LFS.Timestamp() or ""
    local info = {name = config.name or "", heap = node.heap(), id = node.chipid(), lfsTimestamp = lfsTimestamp,
            fwVersion = node.info("sw_version").git_commit_dts,
            modules = node.info("build_config").modules, files = file.list()}
    info = sjson.encode(info)
    res:send(info)
    res:finish()
end)

local function sendLogs()
  local buf = Logger.getlog()
  if #buf > 0 then
    return buf, sendLogs
  end  
end

WebServer.route("/log", function(req, res)
    res:send(nil, 200)
    res:send_header("Connection", "close")
    res:send_header("Content-Type", "text/plain")
    res:send_header("Access-Control-Allow-Origin", "*")
  print("about to send logs")
    res:send(sendLogs)
    res:finish()
end)

WebServer.routes("/log/.*", function(req, res)
    res:send(nil, 200)
    res:send_header("Connection", "close")
    res:send_header("Content-Type", "text/plain")
    res:send_header("Access-Control-Allow-Origin", "*")
    if req.url:sub(6) == "on" then
      Logger.start()
      res:send("started")
    else
      Logger.stop()
      res:send("stoped")
    end
    res:finish()
end)

WebServer.route("/restart", function(req, res)
    res:send(nil, 201)
    res:send_header("Connection", "close")
    res:send_header("Access-Control-Allow-Origin", "*")
    res:finish()
    local f = function() print("posting restart") node.task.post(node.restart) end
    res:csend(f)
end)

WebServer.route("/compileAndSave", function(req, res)

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

  local uri = parseUri(req.url)
  print("filename:", uri.args.name)  
  print("command:", uri.path)
  print("+R", req.method, req.url, node.heap())
  local size
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
  

  myFile = file.open(tempFileName..".lua", "w+")
  req.onheader = function(self, name, value)
    print("+H", name, value)
    if name == "content-length" then 
      size = tonumber(value)
      req.ondata = SaveFile
    end
  end
end)

WebServer.staticRoute("www")


WebServer.startWebServer(80)
