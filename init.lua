
print('init.lua')
	gpio.mode(1,gpio.OUTPUT)
	gpio.write(1,gpio.LOW)
	gpio.mode(2,gpio.OUTPUT)
	gpio.write(2,gpio.LOW)
	gpio.mode(3,gpio.OUTPUT)
	gpio.write(3,gpio.LOW)
	gpio.mode(4,gpio.OUTPUT)
	gpio.write(4,gpio.LOW)
print('heap: ',node.heap(),(function() collectgarbage() return node.heap() end) ())


print ("dofile('start.lua')")

