
print('init.lua')
print('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())

print('loading LFS')
print('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())
pcall(function() dofile('_init.lua') end)

print("starting start.lua")
dofile('start.lua')

