call variables.cmd

@RD /S /Q "%gamePath%\mods\mod%modname%"
XCOPY "%modPath%\release\mods" "%gamePath%\mods" /e /s /y
