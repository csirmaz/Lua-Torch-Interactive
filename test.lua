
require 'dbg.lua'

print("Create this file to interact with the script: " .. dbg.trigger_file)
print([[In the prompt, try:
dbg.print('myvar')
dbg.print('myvar*')
dbg.print('anon4/myvar')
dbg.get('mytable').key = 'value'
dbg.set('arg', false) -- to stop the infinite loop
cont -- to continue running the script]])

local mytable = {5,6,7}
local myvar = "outside"

local function myfunc(arg)
  local myvar = "inside"

  while arg do
    local myvar = "in loop"
    print("Loop - create " .. dbg.trigger_file)
    os.execute("sleep 4")
    dbg.enter_if_file()
  end
end

myfunc("argument")
print(mytable)
