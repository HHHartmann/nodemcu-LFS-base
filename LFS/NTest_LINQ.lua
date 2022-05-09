local N = ...
N = (N or require "NTest")("LINQ")

local LINQ = dofile("LINQ.lua")

local test1 = {a = "alpha", b="Beta", c = "Centauri"}
print(N)

N.test('create', function()

    local result = LINQ(test1):toDict()
    
    ok(eq(type(result), "table"), "type correct")
    ok(eq(result, test1), "all elements there")

end)

N.test('count', function()

    local result = LINQ(test1):count()
    
    ok(eq(result, 3), "all elements there")

end)

N.test('first', function()

    local k,v = LINQ(test1):first()

    nok(eq(k, nil), "key")
    nok(eq(v, nil), "value")

end)

N.test('select switch', function()

    local k,v = LINQ(test1):select(function(k,v) return v,k end):first()

    nok(eq(k, nil), "key")
    nok(eq(v, nil), "value")

    nok(eq(#k, 1), "key")
    ok(eq(#v, 1), "value")

end)

N.test('where single', function()

    local result = LINQ(test1):where(function(k,v) return k == "b" end):toDict()

    ok(eq(LINQ(result):count(), 1), "count")
    ok(eq(result.b, "Beta"), "result")

end)

N.test('selectMany toDict', function()

    local result = LINQ(test1):selectMany(function(k,v) return {key=k, value=v} end):toDict()

    ok(eq(LINQ(result):count(), 2), "count")

    nok(eq(result.key, nil), "key")
    nok(eq(result.value, nil), "value")

end)

N.test('selectMany count', function()

    local result = LINQ(test1):selectMany(function(k,v) return {key=k, value=v} end):count()

    ok(eq(result, 6), "count")

end)

N.test('selectMany with empty sub list', function()

  local var count = 0
  local function selectManyFunc(k,v)
    count = count + 1
    if count == 2 then
      return {}
    else
      return {key=k, value=v}
    end
  end

  local result = LINQ(test1):selectMany(selectManyFunc):count()

  ok(eq(result, 4), "count")

end)


--------------------  Array  -------------------


local test2 = {"a","b","c","d","e"}


N.test('first', function()

    local k,v = LINQ(test2):first()

    ok(eq(k, 1), "key")
    ok(eq(v, "a"), "value")

end)

N.test('where first', function()

    local k,v = LINQ(test2):where(function(k,v) return v == "c" end):first()

    ok(eq(k, 3), "key")
    ok(eq(v, "c"), "value")

end)

N.test('where count', function()

    local result = LINQ(test2):where(function(k,v) return v ~= "c" end):count()

    ok(eq(result, 4), "count")

end)

N.test('toListValue', function()

    local result = LINQ(test2):toListValue()

    ok(eq(result, {"a","b","c","d","e"}), "match")

end)

N.test('toListValue where', function()

    local result = LINQ(test2):where(function(k,v) return v ~= "c" end):toListValue()

    ok(eq(result, {"a","b","d","e"}), "match")

end)








--[[
print("b","Beta")



print())

print(LINQ(test):selectMany(function(k,v) print("orig",k,v) if k == "b" then return {} else return {key=k, value=v} end end):select(function(k,v) print(k,v) return k,v end):count())
-- this returns 2 but should be 4

]]