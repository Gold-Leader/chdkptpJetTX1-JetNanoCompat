--[[
********************************
Version: 1.1

(C)2013 rudi, original for CHDK
(C)2014 msl, adaption for chdkptp
(C)2015 reyalp, use CHDKPTP home for files

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

INI FILE LIBRARY
********************************
usage:
    read ini file to table and write table to ini file
    useable types of data are boolean, number and string
    a simple "filename" without directory and extension is stored to "<chdkptp home>/filename.ini"
    for other location use a full path and filename

bind library
    iniLib = require("iniLib")

get ini table and blank ini table flag for initialization from "<chdkptp home>/filename.ini"
    ini, newini = iniLib.read("filename")

add section, keys and values
    ini.section = { key1 = value1,  key2 = value2 }

write ini table back to ini file (filename is stored in ini tab); result is true for no error on saving
    is_saved = iniLib.write(ini)

special: clean ini file
    ini = {_filename = ini._filename}
    iniLib.write(ini)

]]

local iniLib = {}

iniLib.version = "1.1"

-- begin: LIBRARY INTERNAL FUNCTIONS
-- check and format ini filename
local function inifile(name)
    if type(name) == "string" and #name > 0 then
        -- if name doesn't include directory sep, use chdkptp home path
        if (name:find('['..fsutil.dir_sep_chars()..']') == nil) then
            local dir = get_chdkptp_home(lfs.currentdir())
            name = fsutil.joinpath(dir,name)
        end
        -- add .ini extension
        name = name .. '.ini'
    else
        error('invalid name')
    end
    -- ensure containing path exists
    fsutil.mkdir_parent(name)
    return name
end

-- read ini file
local function iniread(file)
    local tab, new, f = {}, true, io.open(file)
    if f then
        local section
        for line in f:lines() do
            local s = line:match("^%[([%w_]+)%]$")
            if s then
                section = s
                tab[section] = tab[section] or {}
            end
            if section ~= nil then
                local key, value = line:match("^([%w_]+)%s-=%s*(.+)$")
                if key and value then
                    local vstr = value:match([[^"(.+)"$]])
                    if vstr ~= nil then
                        value = vstr
                    else
                        if value == "true" then value = true
                        elseif value == "false" then value = false
                        elseif tonumber(value) then value = tonumber(value)
                        end
                    end
                    tab[section][key] = value
                    new = false
                end
            end
        end
        f:close()
    end
    return tab, new
end

-- write ini file
-- exclude empty sections
local function iniwrite(file, tab)
    local res = false
    local contents = (";chdkptp ini file, version %s\n"):format(iniLib.version)
    for section, s in pairs(tab) do
        if type(s) == "table" and section == section:match("^([%w_]+)$")then
            local newsection = true
            for key, value in pairs(s) do
                if type(value) == "string" then value = ([["%s"]]):format(value) end
                if key == key:match("^([%w_]+)$") and (type(value) == "string" or type(value) == "number" or type(value) == "boolean") then
                    if newsection then
                        contents = contents .. ("\n[%s]\n"):format(section)
                        newsection = false
                    end
                    contents = contents .. ("%s = %s\n"):format(key, tostring(value))
                end
            end
        end
    end
    local f = io.open(file, "w")
    if f then
        f:write(contents)
        f:close()
        res = true
    end
    return res
end
-- end: LIBRARY INTERNAL FUNCTIONS

-- begin: LIBRARY FUNCTIONS
function iniLib.read(name)
    local initab, new = iniread(inifile(name))
    initab._filename = name
    return initab, new
end

function iniLib.write(initab)
    local res = false
    if type(initab) == "table" then
        res = iniwrite(inifile(initab._filename), initab)
    end
    return res
end
-- end: LIBRARY FUNCTIONS

return iniLib
