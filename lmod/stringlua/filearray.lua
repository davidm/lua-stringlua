--[[
 filearray.lua - file with array-like interface.

 Example:
   local FA = require 'filearray'
   local s = FA 'manual.html'
   print(s[100]) -- print 100th byte of file
   s:close()

 Note: access is buffered.
--]]

local SZBLOCK = 1024

local string_sub = string.sub
local table_concat = table.concat
local tostring = tostring

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
function mt:__len() return self.n end
function mt:__index(i)
  i = i - 1
  local ipos = i % SZBLOCK
  local iblock = (i - ipos) / SZBLOCK
  if self.iblock ~= iblock then
    self.fh:seek('set', iblock * SZBLOCK)
    self.block = self.fh:read(SZBLOCK)
    self.iblock = iblock
  end
  return string_sub(self.block, ipos+1, ipos+1)
end
function mt.__substring(bs,sb,se)
  local str = {}
  for p=1,se-sb+1 do str[p] = bs[sb+p-1] end
  return table_concat(str, '')
end

local function new(s)
  local self = setmetatable({block=false, iblock=false}, mt)
  if type(s) == 'string' then  -- convenience
    local fh, msg = io.open(s, 'rb')
    if not fh then return nil, msg end
    self.fh = fh
    self.n = self.fh:seek("end")
    self.owned = true
  elseif io.type(s) == 'file' then
    self.fh = s
    self.n = self.fh:seek("end")
    self.owned = false
  else
    assert(false)
  end
  function self:close()
    if self.owned then self.fh:close() end
    self.fh = nil
    self.owned = false
  end
  return self
end


return new
