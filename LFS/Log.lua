Log = {}

Log.Silent = 1
Log.Error = 2
Log.Trace = 3
Log.Debug = 4


local smartConsolePrint
local logLevel = Log.Debug
local logPrint = smartConsolePrint

Log.SetLogLevel = function(level)
  logLevel = level
end

Log.SetLogOutput = function(func)
  logPrint = func or smartConsolePrint
end

Log.Log = function(level, ...)
  if level > logLevel then return end

  return smartConsolePrint(...)  -- tail call
end

Log.LogError = function(...)
  return Log.Log(Log.Error, ...)  -- tail call
end

Log.LogTrace = function(...)
  return Log.Log(Log.Trace, ...)  -- tail call
end

Log.LogDebug = function(...)
  return Log.Log(Log.Debug, ...)  -- tail call
end

smartConsolePrint = function(...)
  local params = {...}
  for i = 1 , #params do
    if type(params[i]) == "table" then
      params[i] = sjson.encode(params[i])
    end
  end
  
  print(unpack(params))
end

