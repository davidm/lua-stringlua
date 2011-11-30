-- performance test
package.path = 'lmod/?.lua;'..package.path

local isreplaced = true  -- replace string library implementation
local isprofile = true   -- enable profiler
local N = 1              -- number of iterations

if isreplaced then
  local S = require 'stringlua'
  local SA = require 'stringlua.stringarray'
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
end

local prof
if isprofile then
  require "profiler"  -- http://lua-users.org/wiki/PepperfishProfiler
  prof = newProfiler()
  prof:start()
end

for i=1,N do
  dofile 'pm.lua'  -- from Lua 5.1 test suite
end

if isprofile then
  prof:stop()
  local outfile = io.open( "profile.txt", "w" )
  prof:report( outfile )
  outfile:close()
end
