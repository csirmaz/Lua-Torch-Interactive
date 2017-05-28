# Lua-Torch-Interactive

`dbg` is Lua package that stops the execution of a script and uses the Lua debug prompt to
allow interactively inspecting and changing variables.

## Triggering the prompt

Use `dbg.enter()` in the program to drop the user into the prompt.

Alternatively, use `dbg.enter_if_file(triggerfile)` to drop the user into the prompt if
`triggerfile` exists. If not given, the argument defaults to `dbg.trigger_file`, which is a file
in `/tmp/` derived from the current PID.

## Inside the debug prompt

Before displaying the prompt, `dbg` collects and lists the available variables from the
current scope and the parent scopes, and assigns unique names to them.
The variable names may be prefixed by the name
of the current level or function, or '*' may be added to them to disambiguate them.

In the prompt, use:

- `dbg.print('variablename')` or `dbg.p('variablename')` to print the value of a variable.

- `dbg.get('variablename')` or `dbg.g('variablename')` to return the value of a variable
(useful if the variable is a table to modify it).

- `dbg.set('variablename', value)` or `dbg.s('variablename', value)` to change the value
of a variable.

- `dbg.varinfo()` to repeat the list of variables.

- Type `cont` or press `^D` to allow the script to continue.

- Type `^C,^D` or run `os.exit()` to abort.

## Demo

Run `th test.lua` for a demo (using torch).

## License

dbg.lua is copyright (c) 2017 Elod Csirmaz, released under the MIT license.
