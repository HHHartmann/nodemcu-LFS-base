node.setonerror(function(s)
     collectgarbage()
     local f = file.open("www_errors.txt","a")
     f:writeline("==========================: ")
     f:writeline(s)
     f:writeline("")
     f:close()
     print(s)
     node.restart()
  end)





local syncPort = 7785
local broadcastIp = "255.255.255.255"

LINQ = dofile("LINQ.lua")
local msgType = {SYNC="SYNC", SYNCREPLY="SYNCREPLY"}

local syncSocket

local fileDist = {}
local syncCheck
local stateFileName = "FileDistState.json"

local function loadState()
  local file = file.getcontents(stateFileName)
  if file then
    return sjson.decode(file)
  else
    return {}
  end
end

local function saveState(state)
  local data = sjson.encode(state)
  file.putcontents(stateFileName, data)
end

local receiveData

local function sendData(ip, data, sendType)
  collectgarbage()
  data.type = sendType
  local dataToSend = sjson.encode(data)
  data.type = nil
  syncSocket:send(syncPort, ip, dataToSend)
  print("Sent ", #dataToSend, " bytes")
--  receiveData(nil, dataToSend, syncPort, ip)  -- TODO debug only
end

local function sendSync(ip, data)
  print("sendSync", ip, sjson.encode(data))
  sendData(ip, data, msgType.SYNC)
end

local function sendSyncReply(ip, data)
  print("sendSyncReply", sjson.encode(data))
  sendData(ip, data, msgType.SYNCREPLY)
end

local downloadInProgress = false
local function downloadFile(ip, syncFile, meta)
  print("downloadFile", syncFile)
  if downloadInProgress then
    print("download already in progress. Aborting.")
    return
  end
  
  downloadInProgress = true
  local firstRec, subsRec, finalise
  local n, total, size = 0, 0
  local saveFile
  
  local ondisconnect = function(connection)
    connection:on("receive", nil)
    connection:on("disconnection", nil)
    downloadInProgress = false
    collectgarbage("collect")
  end
  
  local con = net.createConnection()
  con:on("connection",function(sck)
      local request = table.concat( {
        "GET /download/"..syncFile.." HTTP/1.1",
        "User-Agent: ESP8266 app (linux-gnu)",
        "Accept: application/octet-stream",
        "Accept-Encoding: identity",
        "Host: "..ip,
        "Connection: close",
        "", ""}, "\r\n")
      print(request)
      collectgarbage()
      sck:send(request)
      sck:on("receive", firstRec)
      sck:on("disconnection", ondisconnect)
    end)
  con:connect(80,ip)
  con = nil

  firstRec = function (sck,rec)
    -- Process the headers; only interested in content length
    local i      = rec:find('\r\n\r\n',1,true) or 1
    local header = rec:sub(1,i+1):lower()
    size         = tonumber(header:match('\ncontent%-length: *(%d+)\r') or 0)
    print(rec:sub(1, i+1))
    if size > 0 then
      sck:on("receive",subsRec)
      saveFile = file.open("~"..syncFile, 'w')
      subsRec(sck, rec:sub(i+4))
    else
      sck:on("receive", nil)
      sck:on("disconnection", nil)
      sck:close()
      print("GET failed")
      downloadInProgress = false
    end
  end

  subsRec = function(sck,rec)
    total, n = total + #rec, n + 1
    if n % 4 == 1 then
      sck:hold()
      node.task.post(0, function() sck:unhold() end)
    end
    print(('%u of %u, '):format(total, size))
    saveFile:write(rec)
    if total >= size then finalise(sck) end
  end

  finalise = function(sck)
    saveFile:close()
    sck:on("receive", nil)
    sck:on("disconnection", nil)
    sck:close()
    local s = file.stat("~"..syncFile)
    if (s and size == s.size) then
      collectgarbage();collectgarbage()
      local destFile = syncFile
      if destFile == "luac.out.old" then
        destFile = "luac.out"
        print("finalizing", syncFile, "as", destFile)
      else
        print("finalizing", syncFile)
      end
      file.remove(destFile)
      file.rename("~"..syncFile, destFile)
      local state = loadState()
      state[syncFile] = meta
      saveState(state)
      if meta.action and #meta.action >= 1 then
        print("executing", meta.action)
        if meta.action == "reboot" then
          node.task.post(function() node.restart() end)
        else 
          if meta.action:sub(1,1) == "!" then
            print(pcall(load(meta.action:sub(2))))
          end
          syncCheck(state)
        end
      end
    else
      print"Invalid save of file"
    end
    downloadInProgress = false
  end

end

local function getNewerFiles(this, other)
  local function isNewer(old, new)
  collectgarbage()
    print(old, new)
    print("old", old and (sjson.encode(old)))
    print("new", new and (sjson.encode(new)))
    if not old then return true end
    if not new then return false end
    return old.version < new.version
  end

  local function hasNewer(k,v)
    print("hasNewer", k, sjson.encode(v))
    return isNewer(this[k], v)
  end

  return LINQ(other):where(hasNewer):toDict()
end

local function receiveSync(ip, updateData)
  collectgarbage()
  local state = loadState()
  print("receiveSync updateData", sjson.encode(updateData))
  print("receiveSync state", sjson.encode(state))
  local newerFiles =  getNewerFiles(updateData, state)
  print("receiveSync newerFiles", sjson.encode(newerFiles))
  if LINQ(newerFiles):first() then
    sendSyncReply(ip, newerFiles)
  end
  local syncFile, meta = LINQ(getNewerFiles(state, updateData)):first()
  if syncFile then
    downloadFile(ip, syncFile, meta)
  end
end

local function receiveSyncReply(ip, updateData)
  collectgarbage()
  local state = loadState()
  print("receiveSyncReply updateData", sjson.encode(updateData))
  print("receiveSyncReply state", sjson.encode(state))
  local syncFile, meta = LINQ(getNewerFiles(state, updateData)):first()
  if syncFile then
    downloadFile(ip, syncFile, meta)
  end
end

function receiveData(socket, data, port, ip)
  print("received", ip, data)
  local success, result = pcall(function() return sjson.decode(data) end )
  if not success then
    print('Invalid JSON received from ', ip, data, result)
    return
  end
  local updateType = result.type
  result.type = nil
  if updateType == msgType.SYNC then
    receiveSync(ip, result)
  elseif updateType == msgType.SYNCREPLY then
    receiveSyncReply(ip, result)
  else
    print('Invalid data comming from ip', ip, '. Invalid type specified:', updateType)
  end
end

syncCheck = function(state)  -- state may be nil
  node.task.post(0, function()
      state = state or loadState()
      sendSync(broadcastIp, state)
  end)
end

function fileDist.Start()
  if not syncSocket then
    syncSocket = net.createUDPSocket();
    syncSocket:listen(syncPort);
    syncSocket:on('receive', receiveData);
  end
  
  syncCheck()
end

function fileDist.Deploy(filename, action)
  local s = file.stat(filename)
  if not s then
    print("file does not exist")
    return
  end

  local state = loadState()
  if state[filename] then
    state[filename].version = state[filename].version +1
    state[filename].size = s.size
    if action then
      state[filename].action = action
    end
  else
    state[filename] = {
      hash = "cxbcdzuf6347",
      version = 1,
      action = action,
      size = s.size
    }
  end
  saveState(state)
  return collectgarbage()
end

local ServingFile = false
WebServer.routes("/download/.*", function(req, res)
    collectgarbage()
    filename = req.url:gsub("/download/","")
    if ServingFile then
      print("serving allready in progress. not serving", filename)
    else
      print("serving", filename)
      ServingFile = true
    end

    local sendFile = file.open(filename)
    local length = file.stat(filename)
    if not length then
      print("file not found", filename)
      res:send(nil, 404)
      res:send_header("Access-Control-Allow-Origin", "*")
      res:send_header("Connection", "close")
      res:send("File not found")
      res:finish()
      ServingFile = false
      return
    end
    
    length = length.size

    res:send(nil, 200)
    res:send_header("Connection", "close")
    res:send_header("Access-Control-Allow-Origin", "*")
    res:send_header("Content-Type", "application/octet-stream")
  
    res.utils.sendRawFile(req, res, sendFile, length, function() print("finished servicng file", filename) ServingFile = false end)
    return collectgarbage()
end)


WebServer.routes("/deploy/.*", function(req, res)
    collectgarbage()
    filename = req.url:gsub("/deploy/","")
    if #filename > 0 then
      local success, result = pcall(fileDist.Deploy, filename)
      syncCheck()

      res:send(nil, 201)
      res:finish()
    else
      res:send(nil, 200)
      res:send_header("Connection", "close")
      res:send_header("Access-Control-Allow-Origin", "*")
      res:send_header("Content-Type", "application/json")
      res:send(sjson.encode(file.list()))
      res:finish()
    end
    return collectgarbage()
end)


FileDist=fileDist  -- TODO debug only
fileDist.Start()  -- TODO debug only

return fileDist

--[[
{
	"filename": {
		"hash": "cxbcdzuf6347",
		"version": 123,
		"action": "reboot/none",
    "size": 123
	}
}


note: all sync sends are UDP broadcasts


Receive SyncCheck:
  check against own state table
  If has_newer_files 
    wait random timespan (0-1 sec)
    if no suficchient update info has been sent by other receiver
      send partial state table with updated files
  If has_older_files
    Download

the download filename is something like "{version}_{filename}.part"
Watch out for max filename length

Download:
  if download file does not exist
    create download file
  Continue Download

Continue Download:
  send stream request with start block to server which sent newer file information (first block is 1 as allways in lua)
  # might make sense to use/enhance http server for that
  # implement filter part to "auth" download requests
  
Receive Stream Request:
  send required blocks in ascending order
  ## each message contain filename and block
  ## or see above for tcp usage


Receive Stream Block:
  Write to file
  if file has correct length
    if file has correct checksum
      rename in place
      update current state table
      perform action (reboot/none)
      Initiate SyncCheck
    else
      set downloaded file to 0 bytes length


Possible states at boot after reset

started file exists
  will continue to download after SyncCheck. If no answer it will just remain in Place.



In dev, files are uploaded by other mechanisms.
To deploy them a function is called which checks the hashes of all local files against the current state table.
If the hash differs a new version is created by incrementing the "version", replacing the hash and calling `Initiate SyncCheck`.
To add entirely new files another function is called.



]]