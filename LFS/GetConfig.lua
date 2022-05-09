
if not file.exists("config.json") then
  print("could not load config.json")
  return {debug = true, runLogger = true, runFTPServer = true, runTelnetServer = true}
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
end

config = nil
print("configuration:", sjson.encode(result))
return result
