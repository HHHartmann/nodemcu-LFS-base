


  local new

  local function first(self)
    return self.iter()
  end


  local function count(self)
    local count = 0
    
    while self.iter() do
      count = count+1
    end
    
    return count
  end


  local function toDict(self)
    local result = {}
    
    for k,v in self.iter do
      result[k] = v
    end
    
    return result
  end


  local function toListValue(self)
    local result = {}
    
    for k,v in self.iter do
      table.insert(result, v)
    end
    
    return result
  end


  local function where(self, predicate)    -- bool predicate(key, value)
    local next = self.iter
    local last = nil
    local function iter()
      local value
      last, value = next()

      if last == nil then return end
      
      while not predicate(last,value) do
        last, value = next()

        if last == nil then return end
      end
      return last, value
    end
    
    return new(iter)
  end


  local function select(self, selector)    -- newKey, newValue selector(key, value)
    local next = self.iter
    local last = nil
    local function iter()
      local value
      last, value = next()
      if last == nil then return end
      
      return selector(last, value)
    end
    
    return new(iter)
  end


  local function selectMany(self, selector)    -- Iterator selector(key, value)   or   dictionary selector(key, value)
    local next = self.iter
    local last = nil
    local manyNext = nil
    local manyLast = nil
    local result
    local function iter()
    
      while true do
        if manyNext then
          local manyValue
          manyLast, manyValue = manyNext(result,manyLast)
          if manyLast == nil then 
            manyNext = nil
            manyLast = nil
          else
            return manyLast, manyValue
          end
        end

        local value
        last, value = next(dict,last)
        if last == nil then return end
        
        result = selector(last, value)

        if type(result) == "function" then
          manyNext = result
        else
          manyNext = pairs(result)
        end
      end
    end
    
    return new(iter)
  end

  new = function(iter)
    return {
      iter = iter, first=first, where=where, select=select, selectMany=selectMany, count=count, toDict=toDict, toListValue=toListValue}
  end

local function LINQ(dict)


  local iterf = pairs(dict)
  local last = nil
  local function iter()
    last = iterf(dict,last)
    if last == nil then
      return
    end

    return last, dict[last]
  end

    return new(iter)
end

return LINQ
