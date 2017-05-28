--[[

"dbg" is Lua package that stops the execution of a script and uses the Lua debug prompt to
allow interactively inspecting and changing variables.

Triggering the prompt
---------------------

Use dbg.enter() in the program to drop the user into the prompt.

Alternatively, use dbg.enter_if_file(triggerfile) to drop the user into the prompt if
triggerfile exists. If not given, the argument defaults to dbg.trigger_file, which is a
filename in /tmp/ derived from the current PID.

Inside the debug prompt
-----------------------

Before displaying the prompt, "dbg" collects and lists the available variables from the
current scope and the parent scopes, and assigns unique names to them.

For the convenience functions available in the debug prompt see the text in dbg.help below.


dbg.lua is copyright (c) 2017 Elod Csirmaz, released under the MIT license.
]]

-- Lua documentation: http://www.lua.org/manual/5.2/manual.html#pdf-debug.debug

local posix = require 'posix'

dbg = {
  trigger_file = "/tmp/prompt" .. posix.getpid().pid, -- the name of the file that triggers a prompt (automatically populated)

  _varinfo = "", -- string listing available variables
  vars = nil -- map of available variables
}

-- Print help
dbg.help = function()
  print([[
Welcome to the Lua prompt. Here you can inspect and modify variables, call functions, etc.
before continuing with your script. The variables available are from the current scope and
the parent scopes. These are listed above. The variable names may be prefixed by the name
of the current level or function, or '*' may be added to them to disambiguate them.

In the prompt, use:

dbg.print('variablename') or dbg.p('variablename') to print the value of a variable.

dbg.get('variablename') or dbg.g('variablename') to return the value of a variable
    (useful if the variable is a table to modify it).

dbg.set('variablename', value) or dbg.s('variablename', value) to change the value
    of a variable.

dbg.varinfo() to repeat the list of variables.

Type 'cont' or press ^D to allow the script to continue.
Type ^C,^D or run 'os.exit()' to abort.
]])
end

-- Disabled - Set up the signal handler
-- See https://luaposix.github.io/luaposix/modules/posix.signal.html
--[[
  local _signal = require "posix.signal"
  _signal.signal(_signal.SIGUSR1, function()
    print("dbg: Signal received")
    dbg.signal_received = true
  end)
--]]


-- Internal function to print a value
dbg._printval = function(v)
  local t = type(v)
  if t == 'string' then
    io.write('"'..v..'"')
  elseif t == 'number' then
    io.write('('..tostring(v)..')')
  elseif t == 'boolean' then
    io.write('<'..tostring(v)..'>')
  elseif t == 'nil' then
    io.write('[nil]')
  elseif t == 'table' or t == 'userdata' then
    print(v) -- use torch's print override
  else
    io.write(tostring(v))
  end    
end

-- Use in prompt: Set a variable
dbg.set = function(nicevarname, newvalue)
  local vard, varname, oldvalue, level, ix = dbg._get(nicevarname)
  if not vard then return end
  local ret = debug.setlocal(level, ix, newvalue)
  if (not ret) or (ret ~= varname) then
    io.write("Internal error #2: ret=")
    dbg._printval(ret)
    io.write("\n")
  else
    io.write(varname .. " = ")
    dbg._printval(oldvalue)
    io.write(" -> ")
    dbg._printval(newvalue)
    io.write("\n")
  end
end

dbg.s = dbg.set

-- Use in prompt: Get a variable (e.g. to change values in it if it is a table)
dbg.get = function(nicevarname)
  local vard, varname, varvalue, _, _ = dbg._get(nicevarname)
  if not vard then return nil end
  return varvalue
end

dbg.g = dbg.get

-- Use in prompt: Print a variable
dbg.print = function(nicevarname)
  local vard, varname, varvalue, _, _ = dbg._get(nicevarname)
  if not vard then return end
  io.write(varname .. " = ")
  dbg._printval(varvalue)
  io.write("\n")
end

dbg.p = dbg.print

-- Internal function
dbg._get = function(nicevarname)
  local vard = dbg.vars[nicevarname]
  if not vard then
    print("Error: Cannot find variable " .. nicevarname)
    return nil
  end
  local level, ix = vard.level+4, vard.ix -- +4 from dbg.enter, debug.debug, dbg.get/set, dbg_get
  local varname, varvalue = debug.getlocal(level, ix)
  -- Sanity check
  if varname ~= vard.varname then
    print("Internal error #1: " .. varname .. " vs " .. vard.varname)
    return nil
  end
  return vard, varname, varvalue, level-1, ix -- as we return, the stack decreases
end

-- Use in prompt: list available variables again
dbg.varinfo = function()
  print(dbg._varinfo)
end

-- Use in the script to drop the user to a prompt if the specified file exists.
-- The file defaults to dbg.trigger_file.
dbg.enter_if_file = function(triggerfile)
  if not triggerfile then triggerfile = dbg.trigger_file end
  
  if posix.stat(triggerfile) then
    os.remove(triggerfile) -- delete file
    dbg.enter(1)
  end
end

-- Use dbg.enter() in the script to drop the user to a prompt
dbg.enter = function(leveloffset)
  dbg.vars = {}
  
  local minlevel = 2 + (leveloffset or 0) -- do not list level 0 (debug.debug) or 1 (dbg.enter) or possibly dbg.enter_if_file
  
  local out = "\nLIST OF VARIABLES"
  
  -- loop through levels
  local level = minlevel
  while true do
  
    local levelinfo = debug.getinfo(level, "n")
    if not levelinfo then break end
    local levelname = levelinfo.name
    if not levelname then levelname = "anon"..level end
    local levelout = "In "..levelname.." ("..level.."):\n"

    -- loop through variables (excluding varargs)
    local ix = 1
    while true do
      local varname, varvalue = debug.getlocal(level, ix)
      if not varname then break end
      
      if
        varname ~= "_" -- exlcude _ variable
        and varname:sub(1,1) ~= "(" -- exclude internal variables
        and type(varvalue) ~= "function" -- exclude functions
      then
      
        -- try to find a unique name to refer to the variable
        local nicevarname = varname
        if dbg.vars[nicevarname] then
          if level ~= minlevel then
            nicevarname = levelname .. "/" .. nicevarname
          end
        end
        while dbg.vars[nicevarname] do
          nicevarname = nicevarname .. "*"
        end
      
        dbg.vars[nicevarname] = {level=level, ix=ix, varname=varname}
        levelout = levelout .."    "..nicevarname
        if nicevarname ~= varname then
          levelout = levelout .." ("..varname..")\n"
        else
          levelout = levelout .."\n"
        end
      
      end
      
      ix = ix + 1
    end
    level = level + 1
    out = levelout .. out
  end
  
  dbg._varinfo = out

  -- Drop into a prompt. This adds one to the stack.
  print(dbg._varinfo .. "\nENTERING DEBUG MODE - dbg.help() for help")
  debug.debug()
end
