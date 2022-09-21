-----------------------------------------------------------------------------------------------------
-- WebServer module
--
-- LICENCE: WebServer://opensource.org/licenses/MIT
-- Gregor Hartmann https://github.com/HHHartmann
------------------------------------------------------------------------------
local collectgarbage, tonumber, tostring = collectgarbage, tonumber, tostring
local utils = {}

--local WebServer
WebServer = {}
do

  local plugins = {}

  -- forward declaration
  local nextFunc

  local function executePlugin(context)
    collectgarbage()
    local plugin = plugins[context.pluginNr]
    node.task.post(function()
        plugin.plugin(context.req, context.res, nextFunc(context), plugin.params)
      end, node.task.LOW_PRIORITY)
  end

  local send404 = function(req, res)
        res:send(nil, 404)
        res:send_header("Connection", "close")
        res:send("URL unknown")
        res:finish()
    end

  nextFunc = function(context)
    context.pluginNr = context.pluginNr + 1
    if #plugins >= context.pluginNr then
      return function() executePlugin(context) end
    else
      return function() send404(context.req, context.res) end
    end
  end

  local lastHandledRequestTime = 0
  local function throttled(req, res)
    if lastHandledRequestTime +1 > tmr.time() then
      print("sending 302 Found")
      res:send(nil, 302)
      res:send_header("Retry-After", 1)
      res:send_header("Location", req.url)
      res:send_header("Access-Control-Allow-Origin", "*")
      res:finish()
      return true
    end
    lastHandledRequestTime = tmr.time()
    return false
  end

  local function runRequest(req, res)
    print("URL:", req.url)
    if throttled(req, res) then return end
    local context = {req=req, res=res, pluginNr=1}
    context.res.utils = utils
    executePlugin(context)
  end



  ------------------------------------------------------------------------------
  -- plugins
  ------------------------------------------------------------------------------


  --[[
  Plugins are called with four parameters:
    req, res    The request and result as passed by httpserver
    Next        A function which can be called if processing should continue
                with the next plugin. Either because the currrent plugin cannot
                handle the request or because it is middleware like authentication.
                If the Next function is not called be sure to call res:finish().
    params      Params passed for the plugin. (can be whatever data type)
  ]]

  local function routePlugin(req, res, Next, params)
    if params.pattern and req.url:find(params.pattern) then
      params.exec(req, res)
    elseif params.url and req.url == params.url then
      params.exec(req, res)
    else
      return Next()
    end
  end


  local function autoRouteStaticPlugin(req, res, Next, params)
    local filename = (params.prefix or "") .. (req.url or ""):gsub("/","_")
    print("cheking file:", filename)
    local testFile = file.open(filename)

    if not testFile then
      return Next() -- url unhandled. Try others (down to inherent 404)
    end
    utils.sendFile(req, res, filename, 0)
  end

  ------------------------------------------------------------------------------
  -- utilities
  ------------------------------------------------------------------------------

  function utils.sendFile(req, res, filename, start)
    start = start or 0
    print("serving:", filename, "start:", start)
    local sendFile = file.open(filename)
    local length = file.stat(filename)
    length = length.size
    sendFile:seek("set", start)
    length = length - start
    if length < 0 then length = 0 end
    res:send(nil, 200)
    --res:send_header("Content-Length", length)  -- we use chunked encoding
    local extension = filename:match(".*%.(.*)") or ""
    extension = extension:lower()
    local mimetypes = {
          json = "application/json",
          js = "application/javascript",
          html = "text/html",
          htm = "text/html",
          css = "text/css",
          txt = "text/plain",
          jpg = "image/jpeg",
          jpeg = "image/jpeg"
        }
    local mimetype = mimetypes[extension] or "text/plain"
    mimetypes = nil
    print(node.heap())
    print("Content-Type", mimetype)
    res:send_header("Content-Type", mimetype)
    utils.sendRawFile(req, res, sendFile, length)
    --res:finish()
  end


  function utils.sendRawFile(req, res, sendFile, length, finishCB)
    local function f()
      collectgarbage()
      local buf = sendFile:read(256)
      print("sending chunk")
      if buf then
        return buf, f
      end
      print("done sending")
      sendFile:close()
      return "", function() finishCB() return nil end  -- discard any return values of finishCB
    end
    collectgarbage()
    print(node.heap())
    print("pushing first f")
    res:finish(f, length)   -- send length bytes served by data function f
  end


  local function normalize(req, res, Next, params)
  --  if req.url:gmatch(".*&") 
  end


--[[
TODO
  add plugin which sets method in res  
    send file
    send redirect ??
    parse URL into params and ancor
  add plugin autoRouteAPI
  add HTTP Method selector
  add concept for receiving long files
]]

  --[[
  Configure which plugins should be applied. May be called several times to define several plugins.
  For each request the first plugin is called which then can handle the request or call its Next function.

  As default there is a 404 handler applied at the end of the list which will be called
  if the request is not handled by any plugin.

  usage:
      use(route, {url="/info", exec=SendInfo })
  ]]
  local function use(plugin, params)
    print("Adding plugin nr", #plugins+1, params and params.desc )
    plugins[#plugins+1] = {plugin=plugin, params=params}
  end


  --[[
  route(url, func)
    params
      url   the url to be handled by this usage
      func  the function(req, res) to be called. res and req are as passed by httpserver

  usage:
      WebServer.route("/info", function(req, res) res:finish("Info Text", 200) end)
  ]]
  local function route(url, func)
    use(routePlugin, {url=url, exec=func, desc=("API for '%s'"):format(url)})
  end


  --[[
  routes(pattern, func)
    params
      pattern   the lua pattern for all urls to be handled by this usage
                include ^ and $ to match the whole URL
      func  the function(req, res) to be called. res and req are as passed by httpserver

  usage:
      WebServer.routes("/switch/.*", function(req, res) res:finish("Info Text", 200) end)
  ]]
  local function routes(pattern, func)
    use(routePlugin, {pattern=pattern, exec=func, desc=("APIs for '%s'"):format(pattern)})
  end


  --[[
  staticRoute(prefix)
    download a file beginning with "prefix" and ending with the URL given
    "/" will be replaced by "_"
    params
      prefix   the prefix which is prepended to the URL to find the filename

  usage:
      WebServer.staticRoute("www")
      will serve file www_news_today when called with URL /news/today
  ]]
  local function staticRoute(prefix)
    use(autoRouteStaticPlugin, {prefix=prefix, desc=("static for '%s'"):format(prefix)})
  end


  ------------------------------------------------------------------------------
  -- WebServer
  ------------------------------------------------------------------------------
  local function startWebServer(port)
    -- add default 404 not found
    -- NOTE: moved to separate function and being called at the end of the plugins
--[[    use(function(req, res, Next, params)     
        res:send(nil, 404)
        res:send_header("Connection", "close")
        res:send("URL unknown")
        res:finish()
    end)]]

    require("httpserver").createServer(port or 80, runRequest)
  end





  ------------------------------------------------------------------------------
  -- HTTP server methods
  ------------------------------------------------------------------------------
  WebServer = {
    startWebServer = startWebServer,
    use = use,
    route = route,
    routes = routes,
    staticRoute = staticRoute,
  }
end

--return WebServer










--use(normalize)





WebServer.route("/info", function(req, res)
    res:send(nil, 200)
    res:send_header("Connection", "close")
    res:send_header("Content-Type", "text/json")
    res:send_header("Access-Control-Allow-Origin", "*")
    local info = {name = config.name or "", heap = node.heap(), id = node.chipid(), files = file.list()}
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


WebServer.startWebServer(80)
