--[[
 tablearray.lua - table with array-like interface.

 Example:
   local TA = require 'tablearray'
   local s = TA {'t', 'e', 's', 't'}
   assert(s[3] == 's') -- access third element
   local s = TA 'test' -- equivalent to above
   assert(s[3] == 's') -- access third element
--]]


local string_sub = string.sub
local table_concat = table.concat

local mt = {}
function mt:__tostring()
  local ts = {}
  for i=1,self.n do ts[#ts+1] = tostring(self[i]) end
  return table_concat(ts)
end
function mt.__eq(a,b)
  if a.n ~= b.n then return false end
  for i=1,a.n do
    if a[i] ~= b[i] then return false end
  end
  return true
end
function mt:__len()
  return self.n
end
function mt.__substring(bs,sb,se)
  local str = setmetatable({}, mt)
  local l = se-sb+1
  for p=1,l do str[p] = bs[sb+p-1] end
  str.n = l
  return str
end

local function new(s)
  local self
  if type(s) == 'string' then  -- convenience
    self = setmetatable({}, mt)
    for i=1,#s do self[i] = string_sub(s, i, i) end
    self.n = #s
  elseif type(s) == 'table' then
    s.n = #s  -- rawlen before setting metatable
    self = setmetatable(s, mt)
  else
    assert(false)
  end
  return self
end

return new
