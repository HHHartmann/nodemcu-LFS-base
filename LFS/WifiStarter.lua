-- Function for starting the server.
-- If you compiled the mdns module, then it will register the server with that name.

local starter = {}

function starter.start(startApp_cb)

  local startApp = function(ip)

    wifiConfig = nil
    collectgarbage()

    startApp_cb(ip)
    if (mdns) then
      mdns.register("nodemcublack", { description="A tiny server", service="http", port=serverPort, location='Earth' })
    end
  end

  
	local wifiConfig = require("wifiConfig")


	-- Tell the chip to connect to the access point

	wifi.setmode(wifiConfig.mode)
	--print('set (mode='..wifi.getmode()..')')

	if (wifiConfig.mode == wifi.SOFTAP) or (wifiConfig.mode == wifi.STATIONAP) then
		print('AP MAC: ',wifi.ap.getmac())
		wifi.ap.config(wifiConfig.apConfig)
		wifi.ap.setip(wifiConfig.apIpConfig)
    dhcp_config ={}
    dhcp_config.start = "192.168.1.100"
    wifi.ap.dhcp.config(dhcp_config)
    cfg =
    {
        ip="192.168.1.1",
        netmask="255.255.255.0",
        gateway="192.168.1.1"
    }
    wifi.ap.setip(cfg)    
	end

	print('chip: ',node.chipid())
	print('heap: ',node.heap())


  if (wifi.getmode() == wifi.STATION) or (wifi.getmode() == wifi.STATIONAP) then

    -- Connect to the WiFi access point and start server once connected.
    -- If the server loses connectivity, server will restart.
    wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(args)
      print("Connected to WiFi Access Point. Got IP: " .. args["IP"])
      startApp(args["IP"])
      wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, function(args)
        print("Lost connectivity! Restarting...")
        node.restart()
      end)
    end)

    if (wifiConfig.mode == wifi.STATION) or (wifiConfig.mode == wifi.STATIONAP) then
      print('Client MAC: ',wifi.sta.getmac())
      for k,v in pairs(wifiConfig.staConfig) do
        print("configuring ", v.ssid)
        wifi.sta.config(v)
      end
    end


    -- What if after a while (30 seconds) we didn't connect? Restart and keep trying.
    local watchdogTimer = tmr.create()
    watchdogTimer:register(30000, tmr.ALARM_SINGLE, function (watchdogTimer)
    local ip = wifi.sta.getip()
      if (not ip) then ip = wifi.ap.getip() end
      if ip == nil then
        print("No IP after a while. Restarting...")
        node.restart()
      else
        --print("Successfully got IP. Good, no need to restart.")
        watchdogTimer:unregister()
      end
      end)
    watchdogTimer:start()
  else
    startApp(wifi.ap.getip())
  end
end

return starter
