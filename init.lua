
print('init.lua')
print('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())


print ("dofile('start.lua')")

