call variables.cmd

::Delete 'Release' folder and create a new one.
rmdir "%modpath%\release" /s /q
mkdir "%modpath%\release"

::Copy over all vanilla .ws scripts.
XCOPY "%modpath%\Source\game" "%modpath%\release\mods\mod%modname%\content\Scripts\game\" /e /s /y

"C:\Program Files\7-Zip\7z.exe" a "%modpath%\release\mums-the-word.zip" "%modpath%\release\mods"