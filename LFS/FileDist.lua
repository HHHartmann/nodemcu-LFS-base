
local syncPort = 7785
local broadcastIp = "255.255.255.255"

LINQ = dofile("LINQ.lua")
local msgType = {SYNC="SYNC", SYNCREPLY="SYNCREPLY"}

local syncSocket

local fileDist = {}
local syncCheck
local stateFileName = "FileDistState.json"

local downloadInProgress = false

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

local function downloadFile(ip, syncFile, meta)
  if meta.action == "delete" then
    local state = loadState()
    state[syncFile] = meta
    saveState(state)
    file.remove(syncFile)
    print("removed", syncFile)
    return syncCheck(state)
  end
  print("downloadFile", syncFile)
  if downloadInProgress then
    print("download already in progress. Aborting.")
  end
  
  local firstRec, subsRec, finalise
  local n, total, size = 0, 0
  local saveFile
  local timeoutTmr
  local connection

  local ondisconnect = function(connection)
    connection:on("receive", nil)
    connection:on("disconnection", nil)
    timeoutTmr:unregister()
    downloadInProgress = false
    syncCheck()
    collectgarbage("collect")
  end
  
  downloadInProgress = true
  timeoutTmr = tmr.create()
  timeoutTmr:alarm(3000, tmr.ALARM_SINGLE, function()
    print("Download timout reached")
    if connection then
      connection:close()
      ondisconnect(connection)
    else
      downloadInProgress = false
      syncCheck()
      collectgarbage("collect")
    end
  end)


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
    connection = sck
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
      print(rec)
      timeoutTmr:unregister()
      downloadInProgress = false
      syncCheck()
    end
  end

  subsRec = function(sck,rec)
    timeoutTmr:start(true)
    total, n = total + #rec, n + 1
    if n % 4 == 1 then
      print("holding")
      sck:hold()
      node.task.post(node.task.LOW_PRIORITY, function() print("unholding") sck:unhold() end)
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
        elseif meta.action == "delete" then
          -- nothing to do here. Should actually never be executed.
        else
          if meta.action:sub(1,1) == "!" then
            print(pcall(load(meta.action:sub(2))))
          end
          syncCheck(state)
        end
      else
        syncCheck(state)
      end
    else
      print("Invalid save of file")
      syncCheck()
    end
    timeoutTmr:unregister()
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

local function removeDummies(state)
  state.lfsTimestamp = nil
  state.fwVersion = nil
end

local function receiveSync(ip, updateData)
  collectgarbage()
  local state = loadState()
  print("receiveSync updateData", sjson.encode(updateData))
  print("receiveSync state", sjson.encode(state))
  removeDummies(state)
  removeDummies(updateData)
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
  removeDummies(state)
  removeDummies(updateData)
  local syncFile, meta = LINQ(getNewerFiles(state, updateData)):first()
  if syncFile then
    downloadFile(ip, syncFile, meta)
  end
end

function receiveData(socket, data, port, ip)
  if downloadInProgress then
    print("download in Progress. Ignoring FileDist packet")
    return
  end
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

local lastSyncCheck = 0
syncCheck = function(state)  -- state may be nil
  if lastSyncCheck < tmr.time() then
    lastSyncCheck = tmr.time()
    node.task.post(node.task.LOW_PRIORITY, function()
        state = state or loadState()
        sendSync(broadcastIp, state)
    end)
  end
end

function fileDist.Start()
  if not syncSocket then
    syncSocket = net.createUDPSocket();
    syncSocket:listen(syncPort);
    syncSocket:on('receive', receiveData);
  end

  if config.smallFs then
    LINQ(file.list("^~")):select(function(k,v) print("removing", k) file.remove(k) return k,v end):count()
  end

  local state = loadState()
  local changed = false

  local lfsTimestamp = node.LFS.Timestamp and node.LFS.Timestamp() or ""
  if not state.lfsTimestamp or state.lfsTimestamp.version ~= lfsTimestamp then
    state.lfsTimestamp = { version = lfsTimestamp }
    changed = true
  end
  
  local fwVersion = node.info("sw_version").git_commit_dts
  if not state.fwVersion or state.fwVersion.version ~= fwVersion then
    state.fwVersion = { version = fwVersion }
    changed = true
  end

  -- TODO remove cleanup after cleanup is done
  state = LINQ(state):select(function(k,v) v.filesize = nil v.hash = nil return k,v end):toDict()
  changed = true

  if changed then
    saveState(state)
  end

  syncCheck(state)
end

function fileDist.Invalidate(filename)
  local state = loadState()
  if state[filename] then
    state[filename].version = 0
    saveState(state)
  else
    print("File not in list")
  end
  syncCheck(state)
  return collectgarbage()
end

function fileDist.Deploy(filename, action)
  local s = file.stat(filename)
  if action == "delete" then
    if s then
      print("file exists")
      return
    end
  elseif not s then
    print("file does not exist")
    return
  end

  local size = (s and s.size) or 0
  local state = loadState()
  if state[filename] then
    state[filename].version = state[filename].version +1
    state[filename].size = size
    if action then
      state[filename].action = action
    end
  else
    state[filename] = {
      version = 1,
      action = action,
      size = size
    }
  end
  saveState(state)
  syncCheck(state)
  return collectgarbage()
end

local ServingFile = false
WebServer.routes("/download/.*", function(req, res)
    collectgarbage()
    filename = req.url:gsub("/download/","")
    local length
    if ServingFile then
      print("serving allready in progress. not serving", filename)
      syncCheck()
    else
      print("serving", filename)
      ServingFile = true
      length = file.stat(filename)
    end

    if not length then
      print("file not found or allready in progress", filename)
      res:send(nil, 404)
      res:send_header("Access-Control-Allow-Origin", "*")
      res:send_header("Connection", "close")
      res:send("File not found")
      res:finish()
      ServingFile = false
      return
    end
    
    length = length.size
    local sendFile = file.open(filename)

    res:send(nil, 200)
    res:send_header("Connection", "close")
    res:send_header("Access-Control-Allow-Origin", "*")
    res:send_header("Content-Type", "application/octet-stream")
  
    res.utils.sendRawFile(req, res, sendFile, length, function() print("finished serving file", filename) ServingFile = false end)
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


FileDist=fileDist
fileDist.Start()  -- TODO debug only

return fileDist
