--[[

LUA MODULE

  stringlua v$(_VERSION) - string.match and string.find reimplemented in Lua.

SYNOPSIS

  local S = require "stringlua"
  local TA = require "stringlua.tablearray" -- strings as tables of chars
  local FA = require "stringlua.filearray"  -- strings as proxy tables to files
  local SA = require "stringlua.stringarray"-- strings as proxy tables to strings
  local s1 = TA {'a','b','c','1','2','3'}
  assert(S.match(s1, SA'%a%d') == TA{'c','1'})
  
DESCRIPTION

  This module partially reimplements Lua 5.1's string library [1] (mainly,
  `string.match` and `string.find`) in Lua. This is a fairly direct port of
  `lstrlib.c` [2] to Lua and therefore is not necessarily the most efficient
  possible.  Strings are represented as arrays of values
  (typically, though not necessarily, chars).  Reimplementing these in Lua
  provides a number of generalizations and possible applications:

  - The pattern matching library can be extended in Lua
  - The pattern matching can match not just strings but also to arrays
      of chars and arrays of arbitrary values, including arrays backed by
      metamethods. The `filearray.lua` example included in the appendix
      allows a large file to be accessed via an array interface, which can
      then be matched by these `string.find`/`string.match` functions, without
      ever loading the entire file into memory at once.
      
  A few examples are given in the test suite (`test.lua`).

API

  The `S` table is similar to the Lua `string` table except the
  functions like `find` and `match` accept and return table arrays of
  characters rather than Lua strings.  Any metamethods on these
  string-like objects are honored, so these tables may be proxy tables.
  A number of additional modules provide various implementations of
  these string-like objects:
  
  - stringlua.tablearray   - tables of characters
  - stringlua.filearray    - proxy table backed by a file
  - stringlua.stringarray  - proxy table backed by a string
  
DEPENDENCIES

  None (other than Lua 5.1 or 5.2).
  
HOME PAGE

  http://lua-users.org/wiki/StringLibraryInLua
  https://github.com/davidm/lua-stringlua

DOWNLOAD/INSTALL

  If using LuaRocks:
    luarocks install lua-stringlua

  Otherwise, download <https://github.com/davidm/lua-stringlua/zipball/master>.
  Alternately, if using git:
    git clone git://github.com/davidm/lua-stringlua.git
    cd lua-stringlua
  Optionally unpack:
    ./util.mk
  or unpack and install in LuaRocks:
    ./util.mk install 
  
REFERENCES
 
  [1] http://www.lua.org/manual/5.1/manual.html#5.4
  [2] http://www.lua.org/source/5.1/lstrlib.c.html

LICENSE
  
  (c) 2008-2011 David Manura.  Licensed under the same terms as Lua (MIT).
  This is based directly on lstrlib.c in Lua 5.1.4.
  Copyright (C) 1994-2008 Lua.org, PUC-Rio.

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
  (end license)
--]]---------------------------------------------------------------------

local M = {_TYPE='module', _NAME='stringlua', _VERSION='0.1.20111203'}

local string = string
local assert = assert
local error = error
local ipairs = ipairs
local getmetatable = getmetatable
local type = type
local unpack = unpack

-- Array index base (0 for C, 1 for L).
local ZERO = 1


--## SECTION: ANSI C functions


-- ANSI C function strpbrk
local function strpbrk(b1,s1, set)
  while 1 do
    local c = b1[s1]
    if c == nil then return end
    if set[c] then return s1 end
    s1 = s1 + 1
  end
end

-- ANSI C function memchr
local function memchr(b,s, c, num)
  for p=s,s+num-1 do
    if b[p] == c then return p end
  end
end

-- ANSI C function memcmp
local function memcmp(b1,s1, b2,s2, num)
  local p2 = s2
  for p1=s1,s1+num-1 do
    local c1, c2 = b1[p1], b2[p2]
    if c1 ~= c2 then
      return c1 > c2 and 1 or -1
    end
    p2 = p2 + 1
  end
  return 0
end


-- ANSI C ANSI character test functions.
-- see also http://www.cplusplus.com/reference/clibrary/cctype/
local allchars; do
  local t = {}
  for i=0,255 do t[i] = i end
  allchars = string.char(unpack(t))
end
local function makechars(pat)
  pat = '^(' .. pat .. ')'
  local set = {}
  for i=1,#allchars do
    local c = allchars:match(pat, i)
    if c then set[c] = true end
  end
  return set
end
local isalpha = makechars'%a'
local iscntrl = makechars'%c'
local isdigit = makechars'%d'
local islower = makechars'%l'
local ispunct = makechars'%p'
local isspace = makechars'%s'
local isupper = makechars'%u'
local isalnum = makechars'%w'
local isxdigit= makechars'%x'
local isnul = {['\0']=true}
local chartest = {
  a = isalpha,
  c = iscntrl,
  d = isdigit,
  l = islower,
  p = ispunct,
  s = isspace,
  u = isupper,
  w = isalnum,
  x = isxdigit,
  z = isnul
}
local tolower = {}
for i=0,255 do
  local c = string.char(i)
  tolower[c]  = c:lower()
end


--## SECTION: luaconf.h


local function LUA_QL(x) return "'" .. x .. "'" end
local LUA_MAXCAPTURES = 32


--## SECTION: Lua API functions

-- Get length of object.  Supports __len metamethod.
local function getlen(o)
  return getmetatable(o).__len(o)
end

local function luaL_checkstack(sz, msg)
  --FIX:ok?
end

local function luaL_checklstring(o)
  assert(type(o) == 'table', 'not string') --:FIX:ok?
  return o,ZERO, getlen(o)
end

local function luaL_checkinteger(o)
  assert(type(o) == 'number', 'not integer') --:FIX:ok?
  return o
end

local function luaL_optinteger(o, d)
  assert(o == nil or type(o) == 'number', 'not integer or nil') --:FIX:ok?
  return o or d
end

local function luaL_error(s)
  error(s)
end


--## SECTION: Utility


-- THe __substring psuedo-metamethod,
-- builds a substring with indices sb..se of the given string
-- bs.
-- newstring(bs,sb,se) -> snew
local function getsubstring(s)
  return getmetatable(s).__substring
end


-- Create set from array.
local function newset(t)
  local res = {}
  for _,v in ipairs(t) do res[v] = true end
  return res
end


--## SECTION: lstrlib.c


-- macro to `unsign' a character
local function uchar(c) return c end

local function str_len(t)
  local _,_, l = luaL_checklstring(t)
  return l
end
M.len = str_len


local function posrelat(pos, len)
  -- relative string position: negative means back from end
  if pos < 0 then pos = pos + len + 1 end
  return pos >= 0 and pos or 0
end

local function str_sub(t, a, b)
  local bs,s,l = luaL_checklstring(t)
  local start = posrelat(luaL_checkinteger(a), l)
  local endp = posrelat(luaL_optinteger(b, -1), l)
  if start < 1 then start = 1 end
  if endp > l then endp = l end
  if start <= endp then  -- :NOTE:
    return getsubstring(t)(bs,s+start-1, s+endp-1)
  else return getsubstring(t)(bs,s, s-1) end
end
M.sub = str_sub


--
-- {======================================================
-- PATTERN MATCHING
-- =======================================================
--

local CAP_UNFINISHED = -1
local CAP_POSITION = -2

local L_ESC    = '%'
local SPECIALS = newset{"^", "$", "*", "+", "?", ".", "(", "[", "%", "-"}




local function check_capture(ms, l)
  l = string.byte(l) -- :NOTE:
  l = l - string.byte'1' -- :NOTE:
  if l < 0 or l >= ms.level or ms.capture[l].len == CAP_UNFINISHED then
    return luaL_error("invalid capture index")
  end
  return l
end


local function capture_to_close(ms)
  local level = ms.level
  for level=level-1,0,-1 do
    if ms.capture[level].len == CAP_UNFINISHED then return level end
  end
  return luaL_error("invalid pattern capture")
end

local function classend(ms, bp,p)
  local cp = bp[p]; p=p+1
  if cp == L_ESC then
    if bp[p] == nil then
      luaL_error("malformed pattern (ends with " .. LUA_QL("%%") .. ")")
    end
    return p+1
  elseif cp == '[' then
    if bp[p] == '^' then p=p+1 end
    repeat  -- look for a `]'
      if bp[p] == nil then
        luaL_error("malformed pattern (missing " .. LUA_QL("]") .. ")")
      end
      local cp = bp[p]; p=p+1
      if cp == L_ESC and bp[p] ~= nil then
        p=p+1  -- skip escapes (e.g. `%]')
      end
    until bp[p] == ']'
    return p+1
  else
    return p
  end
end


local function match_class(c, cl)
  local test = chartest[tolower[cl]]
  if test then
    local res = test[c]
    if not islower[cl] then res = not res end
    return res
  else
    return cl == c
  end
end

local function matchbracketclass(c, bp,p, ec)
  local sig = true
  if bp[p+1] == '^' then
    sig = false
    p=p+1  -- skip the `^'
  end
  while 1 do
    p=p+1; if not (p < ec) then break end
    if bp[p] == L_ESC then
      p=p+1;
      if match_class(c, uchar(bp[p])) then
        return sig
      end
    elseif bp[p+1] == '-' and p+2 < ec then
      p=p+2
      if uchar(bp[p-2]) <= c and c <= uchar(bp[p]) then
        return sig
      end
    elseif uchar(bp[p]) == c then return sig end
  end
  return not sig
end

local function singlematch(c, bp,p, ep)
  local cp = bp[p]
  if cp == '.' then return 1  -- matches any char
  elseif cp == L_ESC then return match_class(c, uchar(bp[p+1]))
  elseif cp == '[' then return matchbracketclass(c, bp,p, ep-1)
  else return uchar(cp) == c
  end
end

local match  -- forward declare

local function matchbalance(ms, bs,s, bp,p)
  if bp[p] == 0 or bp[p+1] == 0 then
    luaL_error("unbalanced pattern")
  end
  if bs[s] ~= bp[p] then return nil
  else
    local b = bp[p]
    local e = bp[p+1]
    local cont = 1
    while 1 do
      s=s+1; if not (s < ms.src_end) then break end
      if bs[s] == e then
        cont=cont-1
        if cont == 0 then return s+1 end
      elseif bs[s] == b then cont=cont+1 end
    end
  end
  return nil  -- string ends out of balance
end


local function max_expand(ms, bs,s, bp,p, ep)
  local i = 0  -- counts maximum expand for item
  while (s+i) < ms.src_end and singlematch(uchar(bs[s+i]), bp,p, ep) do
    i=i+1
  end
  -- keeps trying to match with the maximum repetitions
  while i>=0 do
    local res = match(ms, bs,(s+i), bp,ep+1)
    if res then return res end
    i=i-1  -- else didn't match; reduce 1 repetition to try again
  end
  return nil
end


local function min_expand(ms, bs,s, bp,p, ep)
  while 1 do
    local res = match(ms, bs,s, bp,ep+1)
    if res ~= nil then
      return res
    elseif s < ms.src_end and singlematch(uchar(bs[s]), bp,p, ep) then
      s=s+1  -- try with one more repetition
    else return nil end
  end
end

local function start_capture(ms, bs,s, bp,p, what)
  local res
  local level = ms.level
  if level >= LUA_MAXCAPTURES then luaL_error("too many captures") end
  if not ms.capture[level] then -- :NOTE:
    ms.capture[level] = {}
  end
  ms.capture[level].init = s
  ms.capture[level].len = what
  ms.level = level+1
  res=match(ms, bs,s, bp,p)
  if res == nil then -- match failed?
    ms.level = ms.level - 1  -- undo capture
  end
  return res
end


local function end_capture(ms, bs,s, bp,p)
  local l = capture_to_close(ms)
  local res
  ms.capture[l].len = s - ms.capture[l].init  -- close capture
  res = match(ms, bs,s, bp,p)
  if res == nil then  -- match failed?
    ms.capture[l].len = CAP_UNFINISHED  -- undo capture
  end
  return res
end

local function match_capture(ms, bs,s, l)
  local len
  l = check_capture(ms, l)
  len = ms.capture[l].len
  if ms.src_end-s >= len and
      memcmp(bs,ms.capture[l].init, bs,s, len) == 0
  then
    return s+len
  else return nil end
end



-- local
function match(ms, bs,s, bp,p)
  local goto_init = match
  local function goto_dflt()  -- it is a pattern item
    local ep = classend(ms, bp,p)  -- points to what is next
    local m = s < ms.src_end and singlematch(uchar(bs[s]), bp,p, ep)
    local cep = bp[ep]
    if cep == '?' then  -- optional
      local res
      if m then
        res = match(ms, bs,s+1, bp,ep+1)
        if res ~= nil then return res end
      end
      p=ep+1
      return goto_init(ms, bs,s, bp,p)  -- else return match(ms, s, ep+1)
    elseif cep == '*' then  -- 0 or more repetitions
      return max_expand(ms, bs,s, bp,p, ep)
    elseif cep == '+' then  -- 1 or more repetitions
      return m and max_expand(ms, bs,s+1, bp,p, ep) or nil
    elseif cep == '-' then  -- 0 or more repetitions (minimum)
      return min_expand(ms, bs,s, bp,p, ep)
    else
      if not m then return nil end
      s=s+1; p=ep
      return goto_init(ms, bs,s, bp,p)  -- else return match(ms, s+1, ep)
    end
  end

  -- using goto's to optimize tail recursion
  local cp = bp[p]
  if cp == '(' then -- start capture
    if bp[p+1] == ')' then  -- position capture?
      return start_capture(ms, bs,s, bp,p+2, CAP_POSITION)
    else
      return start_capture(ms, bs,s, bp,p+1, CAP_UNFINISHED)
    end
  elseif cp == ')' then  -- end capture
    return end_capture(ms, bs,s, bp,p+1)
  elseif cp == L_ESC then
    local cp1 = bp[p+1]
    if cp1 == 'b' then  -- balanced string?
      s = matchbalance(ms, bs,s, bp,p+2)
      if s == nil then return nil end
      p=p+4
      return goto_init(ms, bs,s, bp,p)  -- else return match(ms, s, p+4)
    elseif cp1 == 'f' then  -- frontier?
      local ep; local previous
      p = p + 2
      if bp[p] ~= '[' then
        luaL_error("missing " .. LUA_QL("[") .. " after " ..
                   LUA_QL("%%f") .. " in pattern")
      end
      ep = classend(ms, bp,p)  -- points to what is next
      previous = (s == ms.src_init) and nil or bs[s-1]
      if matchbracketclass(uchar(previous), bp,p, ep-1) or
         not matchbracketclass(uchar(bs[s]), bp,p, ep-1)
      then
        return nil
      end
      p=ep
      return goto_init(ms, bs,s, bp,p)  -- else return match(ms, s, ep)
    else
      if isdigit[uchar(bp[p+1])] then  -- capture results (%0-%9)?
        s = match_capture(ms, bs,s, uchar(bp[p+1]))
        if s == nil then return nil end
        p = p + 2
        return goto_init(ms, bs,s, bp,p)  -- else return match(ms, s, p+2)
      end
      return goto_dflt()  -- case default
    end
  
  elseif cp == nil then  -- end of pattern
    return s  -- match succeeded
  elseif cp == '$' then
    if bp[p+1] == nil then  -- is the `$' the last char in pattern?
      return (s == ms.src_end) and s or nil  -- check end of string
    else return goto_dflt() end
  else
    return goto_dflt()
  end
end



local function lmemfind (b1,s1, l1, b2,s2, l2)
  if l2 == 0 then return s1  -- empty strings are everywhere
  elseif l2 > l1 then return nil  -- avoids a negative `l1'
  else
    local init  -- to search for a `*s2' inside `s1'
    l2 = l2 - 1  -- 1st char will be checked by `memchr'
    l1 = l1-l2  -- `s2' cannot be found after that
    while l1 > 0 do
      init = memchr(b1,s1, b2[s2], l1)
      if not init then break end
      init = init + 1   -- 1st char is already checked
      if memcmp(b1,init, b2,s2+1, l2) == 0 then
        return init-1
      else  -- correct `l1' and `s1' to try again
        l1 = l1 - (init-s1)
        s1 = init
      end
    end
    return nil  -- not found
  end
end

local function push_onecapture(ms, i, bs,s,e)
  if i >= ms.level then
    if i == 0 then -- ms->level == 0, too
      return getsubstring(bs)(bs,s,e - 1)  -- add whole match
    else
      luaL_error("invalid capture index")
    end
  else
    local l = ms.capture[i].len
    if l == CAP_UNFINISHED then luaL_error("unfinished capture") end
    if l == CAP_POSITION then
      return ms.capture[i].init - ms.src_init + 1
    else
      local s = ms.capture[i].init
      return getsubstring(bs)(bs,s,s+l-1)
    end
  end
end

local function push_captures(ms, bs,s, e)
  local i
  local nlevels = (ms.level == 0 and s) and 1 or ms.level
  luaL_checkstack(nlevels, "too many captures")
  local results = {}
  for i=0,nlevels-1 do
    results[#results+1] = push_onecapture(ms, i, bs,s, e)
  end
  return unpack(results)  -- number of strings pushed
end


local function str_find_aux(find, s, p, init, plain)
  local bs,s, l1 = luaL_checklstring(s)
  local bp,p, l2 = luaL_checklstring(p)
  init = posrelat(luaL_optinteger(init, 1), l1) + ZERO - 1
  if init < ZERO then init = ZERO
  elseif init > l1+ZERO then init = l1+ZERO end
  if find and (plain or  -- explicit request?
     not strpbrk(bp,p, SPECIALS))  -- or no special characters?
  then
    -- do a plain search
    local s2 = lmemfind(bs,s+init-ZERO, l1-init+ZERO, bp,p, l2)
    if s2 then
      return s2-s+1, s2-s+l2
    end
  else
    local ms = {capture={}} -- MatchState
    local anchor
    if bp[p] == '^' then
      p = p + 1
      anchor = true
    else
      p = ZERO
    end
    local s1 = s+init-ZERO
    ms.src_init = s
    ms.src_end = s+l1
    repeat
      local res
      ms.level = 0
      res = match(ms, bs,s1, bp,p)
      if res ~= nil then
        if find then
          return s1-s+1,  -- start
                 res-s,   -- end
                 push_captures(ms, bs,nil, 0)
        else
          return push_captures(ms, bs,s1, res)
        end
      end
      s1 = s1 + 1
    until not (s1 <= ms.src_end and not anchor)
  end
  return nil  -- not found
end

local function str_find(s, p, init, plain)
  return str_find_aux(true, s, p, init, plain)
end
M.find = str_find

local function str_match(s, p, init)
  return str_find_aux(false, s, p, init)
end
M.match = str_match


return M
