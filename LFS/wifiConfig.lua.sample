
local config = {}

-- Possible modes:   wifi.STATION       : station: join a WiFi network
--                   wifi.SOFTAP        : access point: create a WiFi network
--                   wifi.STATIONAP     : both station and access point
config.mode =  wifi.STATION
 
config.apConfig = {
  ssid="TicTacToe",
  pwd = ""
}
config.apIpConfig = {
  ip = "192.168.1.1",
  netmask = "255.255.255.0",
  gateway = "192.168.1.1",
}

config.staConfig = {}
config.staConfig[0] = {ssid = "id1", pwd = "password"}
config.staConfig[1] = {ssid = "secondWIFI", pwd = "password"}


return config
