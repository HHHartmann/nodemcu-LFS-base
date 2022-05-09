node.startup({command="ws2812.init(ws2812.MODE_SINGLE) ws2812.write(string.rep(string.char(0, 255, 0),31)) dofile('init.lua')"})
print('init.lua')
print('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())

if file.exists("luac.out") then
  print("Flashing new image")
  file.remove("luac.out.try")
  file.rename("luac.out", "luac.out.try")
  local result = node.flashreload('luac.out.try')
  print("Failed flashing new image:", result)
  file.remove("luac.out.fail")
  file.rename("luac.out.try", "luac.out.fail")
end

print('initializing LFS')
print('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())
print(pcall(function() dofile('_init.lua') end))

if file.exists("luac.out.try") then
  if node.LFS.list() then
    file.remove("luac.out.old")
    file.rename("luac.out.try", "luac.out.old")
  else
    print("LFS not loaded. reverting to last image")
    file.remove("luac.out.fail")
    file.rename("luac.out.try", "luac.out.fail")
    file.rename("luac.out.old", "luac.out.try")
    local result = node.flashreload('luac.out.try')
    print("Failed flashing last good image:", result)
    file.remove("luac.out.fail_restore")
    file.rename("luac.out.try", "luac.out.fail_restore")
  end
end

print("starting start.lua")
dofile('start.lua')

