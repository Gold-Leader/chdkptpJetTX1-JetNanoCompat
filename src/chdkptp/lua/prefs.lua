--[[
 Copyright (C) 2010-2021 <reyalp (at) gmail dot com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  with chdkptp. If not, see <http://www.gnu.org/licenses/>.
]]
--[[
system for handling preferences / runtime settings
]]
local m={}
-- preference objects, indexed by name
local prefs={}
-- numeric array of names to maintain fixed order
local order={}
-- unregistered pref values to be picked up on later _add calls
local unreg={}
-- accept unregistered or error?
local allow_unreg

local vtypes={
	boolean={
		-- allow "true" "false", 0,1
		parse=function(val)
			val = val:lower()
			if val == 'true' or tonumber(val) == 1 then
				return true
			end
			if val == 'false' or tonumber(val) == 0 then
				return false
			end
			errlib.throw{etype="bad_arg",msg="invalid value"}
		end,
	},
	string={
		parse=function(val)
			return val
		end,
	},
	number={
		parse=function(val)
			local v = tonumber(val)
			if v then
				return v
			end
			errlib.throw{etype="bad_arg",msg="invalid value"}
		end,
	},
}
--[[
convert string or native value to type specified by vtype.
]]
local function read_val(vtype,val)
	if not vtypes[vtype] then
		errlib.throw{etype="bad_arg",msg='unknown vtype: '..tostring(vtype)}
	end
	if type(val) == vtype then
		return val
	end
	if type(val) ~= 'string' then
		errlib.throw{etype="bad_arg",msg='invalid type: '..type(val)}
	end
	return vtypes[vtype].parse(val)
end

--[[
add pref
name: string, unique name of pref
vtype: value type, described by vtypes above
desc: description text
default: default value, optional, false if not specified
get_fn: optional getter. Should return value and throw on error
set_fn: optional setter. set value, throw on error
]]
function m._add(name,vtype,desc,default,get_fn,set_fn)
	if type(name) ~= 'string' then
		errlib.throw{etype='bad_arg',msg='pref name must be string'}
	end
	if m[name] then
		errlib.throw{etype='bad_arg',msg='pref name conflicts with method: '..tostring(name)}
	end
	if not desc then
		desc = ''
	end
	if default==nil then
		default=false
	end
	-- initial value may not be actual default if config loaded before pref registered
	local init_value = default
	if unreg[name] then
		init_value=unreg[name]
		unreg[name]=nil
	end
	local val = read_val(vtype,init_value)
	table.insert(order,name)
	local p={
		vtype=vtype,
		desc=desc,
		default=read_val(vtype,default),
		set=set_fn,
		get=get_fn,
	}
	if p.set==nil then
		p.set = function(self,val)
			self.value=val
		end
	end
	if p.get==nil then
		p.get = function(self)
			return self.value
		end
	end
	prefs[name]=p
	p:set(val)
end

--[[
remove named pref
ignored if not present
mainly for tests
]]
function m._remove(name)
	local p=prefs[name]
	if not p then
		return
	end
	local index
	for i,name2 in ipairs(order) do
		if name2 == name then
			index = i
			break
		end
	end
	prefs[name] = nil
	table.remove(order,index)
end

--[[
iterator over prefs, in order of registration
]]
function m._each()
	local i=0
	return function()
		i = i + 1
		return order[i],prefs[order[i]]
	end
end

--[[
name=string -- pref name
opts {
	mode='full'|'cmd'|nil -- format
	-- unset  - name=value
	-- 'full' - name, value and description
	-- 'cmd'  - in the form of a set command
	default='skip'|'comment'|nil -- how to handle prefs that have the default value
	-- unset  - no special handling
	-- 'skip' - nil is returned
	-- 'comment' # is prepended
}
returns description or nil
throws bad_arg on invalid name
]]
function m._describe(name,opts)
	opts = util.extend_table({},opts)
	if not prefs[name] then
		errlib.throw{etype='bad_arg',msg='unknown pref: '..tostring(name)}
	end
	local val=prefs[name]:get()
	local is_default = (val == prefs[name].default)
	if is_default and opts.default == 'skip' then
		return
	end
	local r=string.format('%s=%s',name,tostring(val))
	if opts.mode == 'full' then
		r=string.format('%-20s - %s (default %s): %s',r,prefs[name].vtype,prefs[name].default,prefs[name].desc)
	elseif opts.mode == 'cmd' then
		r='set '..r
	end
	if is_default and opts.default == 'comment' then
		r = '# '..r
	end
	return r..'\n'
end

--[[
opts {
	header:string -- if set, output before other headers
	date_header:boolean -- if true, output creation date at start
	version_header:boolean -- if true, output cfgversion command at start
	-- others passed to m._describe
}
]]
function m._describe_all(opts)
	opts = util.extend_table({},opts)
	local r={}
	if opts.header then
		table.insert(r, opts.header)
	end
	if opts.date_header then
		table.insert(r,('# created %s\n'):format(os.date('%Y/%m/%d %H:%M:%S')))
	end
	if opts.version_header then
		table.insert(r,('cfgversion %s\n'):format(chdku.ver.FULL_STR))
	end
	for name,pref in m._each() do
		local desc = m._describe(name,opts)
		-- can be set to skip defaults
		if desc then
			table.insert(r,desc)
		end
	end
	return table.concat(r)
end

function m._save_file(filename,opts)
	opts = util.extend_table({
		mode='cmd',
		default='comment',
		version_header=true,
		date_header=true,
	},opts)
	fsutil.writefile_e(m._describe_all(opts),filename)
end

function m._set(name,value)
	if value == nil then
		value = false
	end
	local p = prefs[name]
	if p then
		local value = read_val(p.vtype,value)
		p:set(value)
	elseif allow_unreg then
		unreg[name] = value
	else
		errlib.throw{etype='bad_arg',msg='unknown pref: ' .. tostring(name)}
	end
end
function m._allow_unreg(allow)
	allow_unreg = allow
end
function m._get(name)
	if prefs[name] then
		return prefs[name]:get()
	end
	errlib.throw{etype='bad_arg',msg='unknown pref: ' .. tostring(name)}
end

--[[
metatable to allow pref values to be accessed from code as prefs.foo
by convention, pref module methods begin with _
]]
local mt={
	__index=function(t,k)
		-- methods
		if m[k] then
			return m[k]
		end
		return m._get(k)
	end,
	__newindex=function(t,k,v)
		m._set(k,v)
	end
}
local proxy = {}
setmetatable(proxy,mt)
return proxy
