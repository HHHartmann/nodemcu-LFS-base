--
-- File: LFS_dummy_strings.lua
--[[
  luac.cross -f generates a ROM string table which is part of the compiled LFS
  image. This table includes all strings referenced in the loaded modules.

  If you want to preload other string constants, then one way to achieve this is
  to include a dummy module in the LFS that references the strings that you want
  to load. You never need to call this module; it's inclusion in the LFS image is
  enough to add the strings to the ROM table. Your application can use any strings
  in the ROM table without incuring any RAM or Lua Garbage Collector (LGC)
  overhead.

  The local preload example is a useful starting point. However, if you call the
  following code in your application during testing, then this will provide a
  listing of the current RAM string table.

do
  local a=debug.getstrings'RAM'
  for i =1, #a do a[i] = ('%q'):format(a[i]) end
  print ('local preload='..table.concat(a,','))
end

  This will exclude any strings already in the ROM table, so the output is the list
  of putative strings that you should consider adding to LFS ROM table.

---------------------------------------------------------------------------------
]]--

-- luacheck: ignore
local preload="\5","%q","(.*)%.l[uc]a?$","(for index)","(for limit)","(for step)",
"=stdin","?.lc;?.lua","@_init.lua",
"API for '/compileAndSave'","API for '/info'","API for '/log'","API for '/restart'","API for '/status'","APIs for '/log/.*'",
"Cannot find '%s' in FS or LFS","DevBoard1","Gartensensor","LUABOX","Lua 5.3","RAM","_LOADED","_PRELOAD","_VERSION","__name","crypto.hash","file.obj","file.vol","gpio.pulse","loaders","loadfile","net.tcpserver","net.tcpsocket","net.udpsocket","onerror","pixbuf.buf","searchers","searchpath","sjson.decoder","sjson.encoder","static for 'www'","stdin","tmr.timer","wifi.packet" ,


"11264530", "13175857", "15683021", "2719629", "3649586", "3849658", "3860104", "3942779", "5937828", "ALRM", "BasicR2", "Batt1", "BatteryPack", "DevBoard1", "HW", "Indoor", "Keller", "Kellersensor", "LED-KellerTreppe", "LED-strip-remote.lua", "Meter.lua", "SEN", "Schalter1", "Schreibtisch", "Sensor.lua", "VEN", "Ventilator", "Wasser.lua", "Wasser Alarm", "Wasser Sensor", "WemosD1", "__runGossip", "__startup", "_startup", "addr", "alarm", "busId", "channels", "debug", "der neue", "devices", "layout", "leds", "location", "name", "pinHigh", "pinLow", "pushButtonPin", "relais", "relaisPin", "runFTPServer", "runGossip", "runLogger", "runTelnetServer", "scl", "sda", "sensors", "signalPin", "smallFs", "startup", "type"