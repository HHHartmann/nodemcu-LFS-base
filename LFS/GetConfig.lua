
if not file.exists("config.json") then
  print("could not load config.json")
  return {debug = true, runLogger = true, runFTPServer = true, runTelnetServer = true}
end

local configSize = file.stat("config.json").size

if file.exists("config_local.json") then
  local local_config = sjson.decode(file.getcontents("config_local.json"))
  if configSize == local_config.configSize then
    print("configuration from cached file:", sjson.encode(local_config))
    return local_config
  end
end


local function copy(source, dest, includeTables)
  for k,v in pairs(source) do
    if includeTables or type(v) ~= "table" then
      dest[k] = v
    end
  end
end

local config = sjson.decode(file.getcontents("config.json"))
local chipid = tostring(node.chipid())
local result = {}
copy(config, result, false)
if config.devices and config.devices[chipid] then
  if config.devices[chipid].HW then
    copy(config.HW[config.devices[chipid].HW], result, true)
  end
  copy(config.devices[chipid], result, true)
else
  print("No configuration found for chip id:", chipid)
end

config = nil
result.configSize = configSize
configJSON = sjson.encode(result)
file.putcontents("config_local.json", configJSON)
print("configuration from new config:", configJSON)
return result
