-----------------------------------------------------------------------------------------------------
-- WebServer module
--
-- LICENCE: WebServer://opensource.org/licenses/MIT
-- Gregor Hartmann https://github.com/HHHartmann
------------------------------------------------------------------------------
local collectgarbage, tonumber, tostring = collectgarbage, tonumber, tostring

--local WebServerCore
local WebServerCore = {}
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

    local context
    
    local function dataAwaiter(req, chunk)
      -- TODO chunk lost for now. Develop concept how to transport
      req.ondata = nil
      return executePlugin(context)
    end


    print("URL:", req.url)
    if throttled(req, res) then return end
    context = {req=req, res=res, pluginNr=1}
    req.ondata = function(req, chunk) dataAwaiter(req, chunk) end
  end


  --[[
  Configure which plugins should be applied. May be called several times to define several plugins.
  For each request the first plugin is called which then can handle the request or call its Next function.

  As default there is a 404 handler applied at the end of the list which will be called
  if the request is not handled by any plugin.

  usage:
      use(route, {url="/info", exec=SendInfo })
          params can be used to transport data to the plugin.
            "desc" is shown when registering
            "headers" is a list of heders which are collected if givn in tha request
            headers will be collected in req.headers
          
  ]]
  local function use(plugin, params)
    print("Adding plugin nr", #plugins+1, params and params.desc )
    plugins[#plugins+1] = {plugin=plugin, params=params}
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
  WebServerCore = {
    startWebServer = startWebServer,
    use = use,
  }
end

return WebServerCore
