local moduleName = ...

print ("loading module", moduleName)

local M = {}
_G[moduleName] = M

local concat = table.concat
local insert = table.insert

local bigLog = {}
local bigLogLen = 0

local smallLog = {}
local smallLogLen = 0

local THRESHOLD = 256


local function record(str)
  if #str + smallLogLen > THRESHOLD then
    if bigLogLen > 5 then
      table.remove(bigLog, 1)
      bigLogLen = bigLogLen -1
    end
    table.insert(bigLog, concat(smallLog)..str)
    smallLogLen = 0
    smallLog = {}
    bigLogLen = bigLogLen +1
  else
    table.insert(smallLog, str)
    smallLogLen = smallLogLen + #str
  end
end


node.output(record, 1)

M.getlog = function()
  if bigLogLen > 0 then
    bigLogLen = bigLogLen -1
    return table.remove(bigLog, 1)
  else
    local temp = concat(smallLog)
    smallLogLen = 0
    smallLog = {}
    return temp
  end
end

return M