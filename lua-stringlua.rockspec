package = "lua-stringlua"
version = "$(_VERSION)"
source = {
   --url = "https://github.com/davidm/lua-stringlua/zipball/v$(_VERSION)",
   url = "git://github.com/davidm/lua-stringlua.git",
   tag='$(_VERSION)'
}
description = {
   summary    = "Lua 5.1 string library partially reimplemented in Lua.",
   detailed   = [[
      Note: use a C binding instead for higher performance.
   ]],
   license    =  "MIT/X11",
   homepage   = "https://github.com/davidm/lua-stringlua",
       -- http://lua-users.org/wiki/StringLibraryInLua
   maintainer = "David Manura <http://lua-users.org/wiki/DavidManura>",
}
dependencies = {
}
build = {
  type = "none",
  install = {
     lua = {
        ["stringlua"] = "lmod/stringlua.lua",
        ["stringlua.filearray"] = "lmod/stringlua/filearray.lua",
        ["stringlua.stringarray"] = "lmod/stringlua/stringarray.lua",
        ["stringlua.tablearray"] = "lmod/stringlua/tablearray.lua"
     }
  }
}
