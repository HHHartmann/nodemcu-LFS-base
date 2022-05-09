local moduleName = ...

print ("loading module", moduleName)

local M = {}

local logData = pipe.create()

local function record(pipe)
  local buf = pipe:read(64)
  while buf do
    logData:write(buf)
    while logData:nrec() > 20 do
      logData:read(64)
    end
    buf = pipe:read(64)
  end
  return false
end

M.getlog = function()
  return logData:read(256) or ""
end

M.start = function(echo)
  -- hook it up
  node.output(record, echo or 1)
end

M.stop = function(echo)
  -- hook it up
  node.output()
end

return M