------------------------------------------------------------------------------
-- HTTP server module
--
-- LICENCE: http://opensource.org/licenses/MIT
-- Vladimir Dronnikov <dronnikov@gmail.com>
------------------------------------------------------------------------------
local collectgarbage, tonumber, tostring = collectgarbage, tonumber, tostring

local http
do
  ------------------------------------------------------------------------------
  -- request methods
  ------------------------------------------------------------------------------
  local make_req = function(conn, method, url)
    return {
      conn = conn,
      method = method,
      url = url,
    }
  end

  ------------------------------------------------------------------------------
  -- response methods
  ------------------------------------------------------------------------------
  local make_res = function(csend, cfini)
    local httpSent = false
    local chunkedOrContentLength -- values are "c" or "l"
    local send = function(self, data, status)
      -- TODO: req.send should take care of response headers!
      if self.send_header and not httpSent then
        csend("HTTP/1.1 ")
        csend(tostring(status or 200))
        -- TODO: real HTTP status code/name table
        csend(" OK\r\n")
        httpSent = true
        -- TODO: send standard response headers, such as Server:, Date:
      end
      if data then
        -- NB: no headers allowed after response body started
        if self.send_header then
          -- we use chunked transfer encoding, to not deal with Content-Length:
          --   response header
          if not chunkedOrContentLength then
            self:send_header("Transfer-Encoding", "chunked")
            chunkedOrContentLength = "c"
          end
          self.send_header = nil
          -- end response headers
          csend("\r\n")
        end
        
        local addChunks = function(data)
          local state = 1
          local chunk
          local function chunker()
            if state == 1 then
              -- send chunked information
              chunk, data = data()
              if #(chunk or "") > 0 then
                state = 2
                return ("%X\r\n"):format(#chunk), data and chunker
              else
                print("chunk 1 no chunk ", chunk, data)
                return nil, data and chunker
              end
            elseif state == 2 then
              -- send actual data
              state = 3
              local localchunk = chunk
              chunk = nil
              return localchunk, chunker
            elseif state == 3 then
              -- finish chunk
              state = 1
              return "\r\n", chunker
            end
          end
          return chunker
        end
        
        if type(data) == "function" then
          if status then  -- status is the length in this case
            -- If total length of data is given, just send 1 chunk
            print("adding big chunk sending method")
            if chunkedOrContentLength == "c" then
              csend(("%X\r\n"):format(status))
            end
            csend(data)
            if chunkedOrContentLength == "c" then
              csend("\r\n")
            end
          else
            -- chunked transfer encoding for each chunk the function returns
            csend(addChunks(data))
          end
        else
          -- chunked transfer encoding
          csend(("%X\r\n"):format(#data))
          csend(data)
          csend("\r\n")
        end
      end
    end
   
    local send_header = function(_, name, value)
      -- NB: quite a naive implementation
      csend(name)
      csend(": ")
      csend(value)
      csend("\r\n")
    end
    
    -- finalize request, optionally sending data
    local finish = function(self, data, status)
      -- NB: res.send takes care of response headers
      if data then
        if type(data) == "function" and status then
          if self.send_header then
            if not chunkedOrContentLength then
              self:send_header("Content-Length", status)
              chunkedOrContentLength = "l"
            end
          end
        end

        self:send(data, status)
      end

      if chunkedOrContentLength == "c" then
        -- finalize chunked transfer encoding
        csend("0\r\n\r\n")
      end

      -- close connection
      cfini()
    end

    --
    local res = {}
    res.send_header = send_header
    res.send = send
    res.finish = finish
    return res
  end

  ------------------------------------------------------------------------------
  -- HTTP parser
  ------------------------------------------------------------------------------
  local http_handler = function(handler)
    return function(conn)
      local csend = (require "fifosock").wrap(conn)

      local req, res
      local buf = ""
      local method, url

      local ondisconnect = function(connection)
        connection:on("receive", nil)
        connection:on("disconnection", nil)
        connection:on("sent", nil)
        collectgarbage("collect")
      end

      local cfini = function()
        csend(function()
          conn:on("sent", nil)
          conn:close()
          ondisconnect(conn)
        end)
      end


      -- header parser
      local cnt_len = 0

      local onheader = function(_, k, v)
        -- TODO: look for Content-Type: header
        -- to help parse body
        -- parse content length to know body length
        if k == "content-length" then
          cnt_len = tonumber(v)
        end
        if k == "expect" and v == "100-continue" then
          csend("HTTP/1.1 100 Continue\r\n")
        end
        -- delegate to request object
        if req and req.onheader then
          req:onheader(k, v)
        end
      end

      -- body data handler
      local body_len = 0
      local ondata = function(_, chunk)
        -- feed request data to request handler
        if not req or not req.ondata then return end
        req:ondata(chunk)
        -- NB: once length of seen chunks equals Content-Length:
        -- ondata(conn) is called
        body_len = body_len + #chunk
        -- print("-B", #chunk, body_len, cnt_len, node.heap())
        if body_len >= cnt_len then
          req:ondata()
        end
      end

      local onreceive = function(connection, chunk)
        -- merge chunks in buffer
        if buf then
          buf = buf .. chunk
        else
          buf = chunk
        end
        -- consume buffer line by line
        while #buf > 0 do
          -- extract line
          local e = buf:find("\r\n", 1, true)
          if not e then break end
          local line = buf:sub(1, e - 1)
          buf = buf:sub(e + 2)
          -- method, url?
          if not method then
            do
              local _
              -- NB: just version 1.1 assumed
              _, _, method, url = line:find("^([A-Z]+) (.-) HTTP/1.1$")
            end
            if method then
              -- make request and response objects
              req = make_req(connection, method, url)
              res = make_res(csend, cfini)
            end
            -- spawn request handler
            handler(req, res)
          -- header line?
          elseif #line > 0 then
            -- parse header
            local _, _, k, v = line:find("^([%w-]+):%s*(.+)")
            -- header seems ok?
            if k then
              k = k:lower()
              onheader(connection, k, v)
            end
          -- headers end
          else
            -- NB: we explicitly reassign receive handler so that
            --   next received chunks go directly to body handler
            connection:on("receive", ondata)
            -- NB: we feed the rest of the buffer as starting chunk of body
            ondata(connection, buf)
            -- buffer no longer needed
            buf = nil
            -- parser done
            break
          end
        end
      end

      conn:on("receive", onreceive)
      conn:on("disconnection", ondisconnect)
    end
  end

  ------------------------------------------------------------------------------
  -- HTTP server
  ------------------------------------------------------------------------------
  local srv
  local createServer = function(port, handler)
    -- NB: only one server at a time
    if srv then srv:close() end
    srv = net.createServer(net.TCP, 15)
    -- listen
    srv:listen(port, http_handler(handler))
    return srv
  end

  ------------------------------------------------------------------------------
  -- HTTP server methods
  ------------------------------------------------------------------------------
  http = {
    createServer = createServer,
  }
end

return http
