print('start.lua')

--node.egc.setmode(node.egc.ON_MEM_LIMIT, 4096)
wifi.setphymode(wifi.PHYMODE_N)

local esp01 = node.chipid() == 1757122
local signalPin = nil
-- signalPin = 4
if esp01 then
	signalPin = 10  -- on esp 01  =  GPIO1  =  TX
end

local function startup()
	print('loading LFS')
	print('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())
	dofile('_init.lua')

	
end

local function netUtilities()
	
	print('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())
	print('Starting ftp server')

	require("ftpserver").createServer("test","12345","dbg")
	print('Starting telnet server')
	require("telnet"):open()
	print('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())
end

local function applicationStartup()
	print('Starting Application')
	print('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())
end

local function startNetwork(cb)
	dofile("WifiStarter.lua").start(cb)
  return true  -- actually return anything
end

local function globalStart()
    startup()
    startup2()
end

print('calling bootprotect')

dofile("bootprotect.lua").start(signalpin, 10,   startup, startNetwork, netUtilities, applicationStartup)
