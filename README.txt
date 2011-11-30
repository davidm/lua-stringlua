The following module (stringlua.lua) partially reimplements Lua's string
library (mainly `string.match` and `string.find`) in Lua 5.1. This is a
fairly direct port of [lstrlib.c] to Lua.  Reimplementing these in Lua
provides a number of generalizations and possible applications:

The pattern matching library can be extended in Lua
The pattern matching can match not just strings but also to arrays of chars
and arrays of arbitrary values, including arrays backed by metamethods.
The filearray.lua example included in the appendix allows a large file to be
accessed via an array interface, which can then be matched by these
`string.find`/`string.match` functions, without ever loading the entire file
into memory at once.
A few examples are given in the test suite (test.lua).

http://lua-users.org/wiki/StringLibraryInLua

MIT License
