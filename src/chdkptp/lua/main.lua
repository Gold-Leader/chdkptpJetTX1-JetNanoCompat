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
util=require'util'
util:import()
errutil=require'errutil'
ustime=require'ustime'
ticktime=require'ticktime'
fsutil=require'fsutil'
prefs=require'prefs'
varsubst=require'varsubst'
lvutil=require'lvutil'
chdku=require'chdku'
cli=require'cli'
exp=require'exposure'
dng=require'dng'
dngcli=require'dngcli'

--[[
Command line arguments
--]]
local function bool_opt(rest)
	if rest == '-' then
		return true,false
	elseif rest ~= '' then
		return false
	end
	return true,true
end

-- one of 'gui', 'cli', 'batch' after options evaluated
local run_mode
-- option values
local start_options = {}

local cmd_opts = {
	{
		opt="g",
		help="start GUI - default if GUI available and no options given",
		process=bool_opt,
	},
	{
		opt="i",
		help="start interactive cli",
		process=bool_opt,
	},
	{
		opt="c",
		help='connect at startup, with optional device spec e.g. -c"-d001 -bbus-0"',
		process=function(rest)
			if rest then
				start_options.c = rest
			else
				start_options.c = true
			end
			return true,start_options.c
		end,
	},
	{
		opt="e",
		help='execute cli command, multiple allowed, e.g -e"u DISKBOOT.BIN" -ereboot',
		process=function(rest)
			if type(start_options.e) == 'table' then
				table.insert(start_options.e,rest)
			else
				start_options.e = {rest}
			end
			return true,start_options.e
		end,
	},
	{
		opt="r",
		help='specify startup command file, if no file given skip default startup files',
		process=function(rest)
			if rest and rest ~= '' then
				start_options.r = rest
			else
				start_options.r = true
			end
			return true,start_options.r
		end,
	},
	{
		opt="h",
		help="help",
		process=bool_opt,
	},
}

local function print_help()
	printf(
[[
CHDK PTP control utility
Usage: chdkptp [options]
Options:
]])
	for i=1,#cmd_opts do
		printf(" -%-2s %s\n",cmd_opts[i].opt,cmd_opts[i].help)
	end
end

-- defaults TODO from prefs
function process_options(args)
	local cmd_opts_map = {}
	local i
	for i=1,#cmd_opts do
		start_options[cmd_opts[i].opt] = false
		cmd_opts_map[cmd_opts[i].opt] = cmd_opts[i]
	end

	while #args > 0 do
		local arg = table.remove(args,1)
		local s,e,cmd,rest = string.find(arg,'^-([a-zA-Z0-9])=?(.*)')
--		printf("opt %s rest (%s)[%s]\n",tostring(cmd),type(rest),tostring(rest))
		if s and start_options[cmd] ~= nil then
			local r,val=cmd_opts_map[cmd].process(rest,args)
			if r then
				start_options[cmd] = val
			else
				errf("malformed option %s\n",arg)
			end
		else
			errf("unrecognized argument %s\n",arg)
			invalid = true
		end
	end

	if start_options.h or invalid then
		print_help()
		return true
	end
end

--[[
return directory for rc files etc
def_path can be used to set the default if nothing reasonable is found, default nil
]]
function get_chdkptp_home(def_path)
	local path=sys.getenv('CHDKPTP_HOME')
	if not path then
		path=sys.getenv('HOME')
		if sys.ostype() == 'Windows' and not path then
			path=sys.getenv('USERPROFILE')
		end
		if path then
			if sys.ostype() == 'Windows' then
				path=path..'/_chdkptp'
			else
				path=path..'/.chdkptp'
			end
		else
			return def_path
		end
	end
	return fsutil.normalize_dir_sep(path)
end

function exec_rc_file(path)
	prefs._allow_unreg(true) -- allow currently unknown prefs to be set
	local status, msg=cli:execfile(path)
	prefs._allow_unreg(false)
	if not status then
		warnf('rc %s failed: %s\n',path,tostring(msg))
		return false
	end
	return true
end

function get_rc_sfx()
	if run_mode == 'gui' then
		return '_gui'
	end
	return ''
end

function get_user_rc_name()
	return 'user'..get_rc_sfx()..'.chdkptp'
end

function get_auto_rc_name()
	return 'autosave'..get_rc_sfx()..'.chdkptp'
end

function do_rc_files()
	-- -r with no file, skip all startup files
	if start_options.r == true then
		return
	end
	local user_rc, auto_rc
	-- no -r at all, use default names
	if not start_options.r then
		local path=get_chdkptp_home()
		if not path then
			return
		end
		auto_rc=fsutil.joinpath(path,get_auto_rc_name())
		user_rc=fsutil.joinpath(path,get_user_rc_name())
	-- -r, use specified file only
	else
		user_rc = start_options.r
	end
	if auto_rc and lfs.attributes(auto_rc,'mode') == 'file' then
		exec_rc_file(auto_rc)
	end
	if lfs.attributes(user_rc,'mode') == 'file' then
		exec_rc_file(user_rc)
	else
		-- if file specified on the command line, warn when not found
		if start_options.r then
			warnf('rc %s not found\n',user_rc)
		end
	end
end

function write_autosave_rc_file()
	local path=get_chdkptp_home()
	if not path then
		return
	end
	local auto_rc=fsutil.joinpath(path,get_auto_rc_name())
	prefs._save_file(auto_rc,{header=([[
# Auto-generated file. Defaults commented with #
# To override settings, edit %s
]]):format(get_user_rc_name())})
end

function do_autosave_rc_file()
	if prefs.config_autosave then
		write_autosave_rc_file()
	end
end

function do_connect_option()
	if start_options.c then
		local cmd="connect"
		if type(start_options.c) == 'string' then
			cmd = cmd .. ' ' .. start_options.c
		end
		cli:print_status(cli:execute(cmd))
	end
end

function do_execute_option()
	if start_options.e then
		for i=1,#start_options.e do
			local status=cli:print_status(cli:execute(start_options.e[i]))
			-- TODO os.exit here is ugly, but no simple way to break out
			if not status and prefs.cli_error_exit then
				os.exit(1)
			end
		end
	end
end

local function check_versions()
	if prefs.warn_deprecated and util.is_lua_ver(5,1) then
		util.warnf("Lua 5.1 is deprecated\n")
	end
	local v=chdk.program_version()
	if v.MAJOR ~= 0 or v.MINOR ~= 7 then
		error("incompatible chdkptp binary version")
	end
	-- TODO could check IUP and CD, but need to be initialized
end

function do_gui_startup()
	run_mode = 'gui'
	printf('starting gui...\n')
	if guisys.init() then
		gui=require('gui')
	elseif guisys.initgtk() then
		gui=require('gtk_gui')
	else
		printf('gui not supported\n')
		os.exit(1)
	end
	do_rc_files()
	check_versions()
	gui:run()
end

local function do_no_gui_startup()
	-- i is overridden to on when CLI started by default
	if start_options.i then
		run_mode = 'cli'
	else
		run_mode = 'batch'
	end
	do_rc_files()
	check_versions()
	do_connect_option()
	do_execute_option()
	if start_options.i then
		cli:run()
		do_autosave_rc_file()
	end
end
prefs._add('config_autosave','boolean','auto save config variables on exit',false)
prefs._add('warn_deprecated','boolean','warn on deprecated libraries',true)
prefs._add('core_verbose','number','ptp core verbosity',0,
	function(self)
		return corevar.get_verbose()
	end,
	function(self,val)
		corevar.set_verbose(val)
	end
)
-- keep lua code backward compatible with older binaries
if type(chdk.get_usb_reset_on_close) == 'function' then
-- some linux configurations seems to fail on reconnect if not used
prefs._add('usb_reset_on_close','boolean','issue USB device reset on connection close',sys.ostype() ~= 'Windows',
	function(self)
		return chdk.get_usb_reset_on_close()
	end,
	function(self,val)
		chdk.set_usb_reset_on_close(val)
	end
)
end
prefs._add('err_trace','string',"stack trace on error, values: 'always', 'critical', 'never'",'critical',
	function(self)
		return errutil.do_traceback
	end,
	function(self,val)
		if not util.in_table({'always','critical','never'},val) then
			errlib.throw{etype='bad_arg',msg='invalid value'}
		end
		errutil.do_traceback = val
	end
)

con=chdku.connection()
dngcli.init_cli()

-- Lua 5.3 compatability stuff
loadstring = loadstring or load
table.maxn = table.maxn or sys.maxn
unpack = unpack or function(args,i,j) return table.unpack(args,i,j) end

local args = sys.getargs()
if #args > 0 then
	process_options(args)
	if start_options.g then
		do_gui_startup()
	else
		do_no_gui_startup()
	end
-- if no options, start gui if available or cli if not
elseif guisys.caps().IUP or guisys.caps().GTK then
	do_gui_startup()
else
	start_options.i=true
	do_no_gui_startup()
end
-- set exit status if last CLI command failed
-- TODO may want different codes for different kinds of errors, combine with existing value?
if not cli.last_status then
	sys.set_exit_value(1)
end
