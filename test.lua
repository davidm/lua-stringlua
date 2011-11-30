-- basic tests of stringlua.lua
package.path = 'lmod/?.lua;'..package.path

local S = require "stringlua"

-- a few example table array interfaces
local TA = require "stringlua.tablearray"
local FA = require "stringlua.filearray"
local SA = require "stringlua.stringarray"

local function tuple(...) return {n=select('#',...), ...} end

-- test on array of chars
local s1 = TA'abc123def{45}'
assert(S.match(s1, SA'%d%a') == TA'3d')
assert(S.match(s1, SA'%d(%a)') == TA'd')
assert(S.match(s1, SA'%b{}') == TA'{45}')
assert(S.match(TA'23', SA'2') == TA'2')
assert(S.sub(s1,1,1) == TA'a')
assert(S.sub(s1,1,-1) == s1)
assert(S.len(s1) == 13)

-- test on file array
-- Run test on Lua 5.1.4 manual (from Lua distribution).
local s = FA 'manual.html'
if s then
  --print(s)
  assert(S.match(s,TA'block ::= (%w+)') == 'chunk')
  assert(S.match(s,TA'(%b<>)setfenv') == '<code>')
  s:close()
else
  print 'WARNING: manual.html not tested'
end

-- test on array of non-chars
assert(S.match(TA{2,false,"test","test",2}, TA{false,"test", '+'})
 == TA{false,"test", "test"})

-- Replace Lua functions with reimplementations.
-- and then run tests from Lua 5.1. test suite
-- http://www.inf.puc-rio.br/~roberto/lua/lua5.1-tests.tar.gz
function string.find(s1, s2, init, plain)
  return S.find(SA(s1), SA(s2), init, plain)
end
function string.match(s1, s2, init)
  return S.match(SA(s1), SA(s2), init)
end
function string.sub(s, a, b)
  return S.sub(SA(s), a, b)
end
function string.len(s)
  return S.len(SA(s))
end
local f = loadfile 'strings.lua'
if f then f() else print 'WARNING: strings.lua not tested' end
local f = loadfile 'pm.lua'
if f then f() else print 'WARNING: pm.lua not tested' end

print'DONE'
