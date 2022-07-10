print('start.lua')


config = dofile("GetConfig.lua")

--node.egc.setmode(node.egc.ON_MEM_LIMIT, 4096)
wifi.setphymode(wifi.PHYMODE_N)

local esp01 = node.chipid() == 1757122
local signalPin = config.signalPin
-- signalPin = 4
if esp01 then
	signalPin = 10  -- on esp 01  =  GPIO1  =  TX
end

local function startup()
	gpio.mode(1,gpio.OUTPUT)
	gpio.write(1,gpio.LOW)
	gpio.mode(2,gpio.OUTPUT)
	gpio.write(2,gpio.LOW)
	gpio.mode(3,gpio.OUTPUT)
	gpio.write(3,gpio.LOW)
	gpio.mode(4,gpio.OUTPUT)
	gpio.write(4,gpio.LOW)

  local f = file.open("www_errors.txt","a")
  f:writeline("------------- "..sjson.encode({node.bootreason()}))
  f:close()


	pcall(function() require("LED-strip") end)
end

local function logger()
  Logger = require("Logger")
  if config.runLogger then
    print("activating Logger")
    Logger.start()
  else
    print("deactivating Logger")
    Logger.stop()
  end
end

local function netUtilities()
	
	print('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())

  if config.runFTPServer then
    print('Starting ftp server')

    require("ftpserver").createServer("test","12345","dbg")
  end

  if config.runTelnetServer then
    print('Starting telnet server')
    require("telnet"):open()
    print('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())
  end
end

local function gossipStartup()
	print('Starting gossip')
  local gossipConfig = {
      seedList = {},
      roundInterval = 30000,
      comPort = 5000,
      debug = true,
      debugOutput = function(message) print('Gossip says: ', message); end
  }

  gossip = require ("gossip")
  gossip.setConfig(gossipConfig)
  gossipConfig = nil
  gossip.start()
  gossip.pushGossip(nil, '255.255.255.255')  -- broadcast to announce new instance
end

local function httpServer()
	print('Starting http server')
	--dofile("IDESupport.lua")
	dofile("WebServer.lua")
	print('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())
end

local function applicationStartup()
	print('Starting ApplicationStart.lua')
  dofile("ApplicationStart.lua")
	print('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())
end

local function startNetwork(cb)
	dofile("WifiStarter.lua").start(cb)
  return true  -- actually return anything
end

print('calling bootprotect')


dofile("bootprotect.lua").start(signalpin, 10,   logger, startup, startNetwork, netUtilities, gossipStartup, httpServer, applicationStartup)
