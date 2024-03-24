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

      print("sending 302 Found")
      res:send(nil, 302)
      res:send_header("Location", req.url)
      res:send_header("Access-Control-Allow-Origin", "*")
    if throttled(req, res) then return end
  local WebServerCore = require("WebServerCore")


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
    if #filename >= 32 then
      return Next()
    end
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
      return "", function() if finishCB then finishCB() end return nil end  -- discard any return values of finishCB
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
  route(url, func)
    params
      url   the url to be handled by this usage
      func  the function(req, res) to be called. res and req are as passed by httpserver

  usage:
      WebServer.route("/info", function(req, res) res:finish("Info Text", 200) end)
  ]]
  local function route(url, func)
    WebServerCore.use(routePlugin, {url=url, exec=func, desc=("API for '%s'"):format(url)})
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
    WebServerCore.use(routePlugin, {pattern=pattern, exec=func, desc=("APIs for '%s'"):format(pattern)})
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
    WebServerCore.use(autoRouteStaticPlugin, {prefix=prefix, desc=("static for '%s'"):format(prefix)})
  end


  ------------------------------------------------------------------------------
  -- WebServer
  ------------------------------------------------------------------------------
  local function startWebServer(port)
    WebServerCore.startWebServer(port)
  end





  ------------------------------------------------------------------------------
  -- HTTP server methods
  ------------------------------------------------------------------------------
  WebServer = {
    startWebServer = startWebServer,
    use = WebServerCore.use,
    route = route,
    routes = routes,
    staticRoute = staticRoute,
    utils = utils
  }
end

return WebServer

