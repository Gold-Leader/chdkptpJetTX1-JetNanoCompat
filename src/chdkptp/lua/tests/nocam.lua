--[[
 Copyright (C) 2012-2021 <reyalp (at) gmail dot com>
  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  with chdkptp. If not, see <http://www.gnu.org/licenses/>.

--]]
--[[
tests that do not depend on the camera
]]
local testlib = require'testlib'
-- module
local m={}

-- assert with optional level for line numbers
local function tas(cond,msg,level)
	if not level then
		level = 3
	end
	if cond then
		return
	end
	error(msg,level)
end


local function spoof_fsutil_ostype(name)
	fsutil.ostype = function()
		return name
	end
end
local function unspoof_fsutil_ostype()
	fsutil.ostype = sys.ostype
end

local function spoof_con(methods)
	local _saved_con = con

	local spoof = util.extend_table({},methods)
	spoof._unspoof = function()
		con = _saved_con
	end
	con = spoof
end

local tests=testlib.new_test({
'nocam',
{{
	'argparser',
	function()
		local function get_word(val,eword,epos)
			local word,pos = cli.argparser:get_word(val)
			tas(word == eword,tostring(word) .. ' ~= '..tostring(eword))
			tas(pos == epos,tostring(pos) .. "~= "..tostring(epos))
		end
		get_word('','',1)
		get_word('whee','whee',5)
		get_word([["whee"]],'whee',7)
		get_word([["'whee'"]],[['whee']],9)
		get_word([['"whee"']],[["whee"]],9)
		get_word([['whee']],'whee',7)
		get_word([[\whee\]],[[\whee\]],7)
		get_word("whee foo",'whee',5)
		get_word([["whee\""]],[[whee"]],9)
		get_word([['whee\']],[[whee\]],8)
		get_word("'whee ",false,[[unclosed ']])
		get_word([["whee \]],false,[[unexpected \]])
		get_word('wh"e"e','whee',7)
		get_word('wh""ee','whee',7)
		get_word([[wh"\""ee]],[[wh"ee]],9)
	end,
},
{
	'dirname',
	function()
		testlib.assert_eq(fsutil.dirname('/'),'/')
		testlib.assert_eq(fsutil.dirname('//'), '/')
		testlib.assert_eq(fsutil.dirname('/a/b/'), '/a')
		testlib.assert_eq(fsutil.dirname('//a//b//'), '//a')
		testlib.assert_eq(fsutil.dirname(), nil)
		testlib.assert_eq(fsutil.dirname('a'), '.')
		testlib.assert_eq(fsutil.dirname(''), '.')
		testlib.assert_eq(fsutil.dirname('/a'), '/')
		testlib.assert_eq(fsutil.dirname('a/b'), 'a')
	end
},
{
	'dirname_win',
	function()
		testlib.assert_eq(fsutil.dirname('c:\\'), 'c:/')
		testlib.assert_eq(fsutil.dirname('c:'), 'c:')
	end,
	setup=function()
		spoof_fsutil_ostype('Windows')
	end,
	cleanup=function()
		unspoof_fsutil_ostype()
	end,
},
{
	'basename',
	function()
		testlib.assert_eq(fsutil.basename('foo/bar'), 'bar')
		testlib.assert_eq(fsutil.basename('foo/bar.txt','.txt'), 'bar')
		testlib.assert_eq(fsutil.basename('foo/bar.TXT','.txt'), 'bar')
		assert(fsutil.basename('foo/bar.TXT','.txt',{ignorecase=false})=='bar.TXT')
		testlib.assert_eq(fsutil.basename('bar'), 'bar')
		testlib.assert_eq(fsutil.basename('bar/'), 'bar')
		testlib.assert_eq(fsutil.basename('bar','bar'), 'bar')
	end,
},
{
	'basename_win',
	function()
		testlib.assert_eq(fsutil.basename('c:/'), nil)
		testlib.assert_eq(fsutil.basename('c:/bar'), 'bar')
	end,
	setup=function()
		spoof_fsutil_ostype('Windows')
	end,
	cleanup=function()
		unspoof_fsutil_ostype()
	end,
},
{
	'basename_cam',
	function()
		testlib.assert_eq(fsutil.basename_cam('A/'), nil)
		testlib.assert_eq(fsutil.basename_cam('A/DISKBOOT.BIN'), 'DISKBOOT.BIN')
		testlib.assert_eq(fsutil.basename_cam('bar/'), 'bar')
	end,
},
{
	'dirname_cam',
	function()
		testlib.assert_eq(fsutil.dirname_cam('A/'), 'A/')
		testlib.assert_eq(fsutil.dirname_cam('A/DISKBOOT.BIN'), 'A/')
		testlib.assert_eq(fsutil.dirname_cam('bar/'), nil)
		testlib.assert_eq(fsutil.dirname_cam('A/CHDK/SCRIPTS'), 'A/CHDK')
	end,
},
{
	'splitjoin_cam',
	function()
		testlib.assert_eq(fsutil.joinpath(unpack(fsutil.splitpath_cam('A/FOO'))), 'A/FOO')
		testlib.assert_eq(fsutil.joinpath(unpack(fsutil.splitpath_cam('foo/bar/mod'))), 'foo/bar/mod')
	end,
},
{
	'joinpath',
	function()
		testlib.assert_eq(fsutil.joinpath('/foo','bar'), '/foo/bar')
		testlib.assert_eq(fsutil.joinpath('/foo/','bar'), '/foo/bar')
		testlib.assert_eq(fsutil.joinpath('/foo/','/bar'), '/foo/bar')
		testlib.assert_eq(fsutil.joinpath('/foo/','bar','/mod'), '/foo/bar/mod')
	end,
},
{
	'joinpath_win',
	function()
		testlib.assert_eq(fsutil.joinpath('/foo\\','/bar'), '/foo\\bar')
	end,
	setup=function()
		spoof_fsutil_ostype('Windows')
	end,
	cleanup=function()
		unspoof_fsutil_ostype()
	end,
},
{
	'fsmisc',
	function()
		testlib.assert_eq(fsutil.joinpath(unpack(fsutil.splitpath('/foo/bar/mod'))), '/foo/bar/mod')
		testlib.assert_eq(fsutil.joinpath(unpack(fsutil.splitpath('foo/bar/mod'))), './foo/bar/mod')
	end,
},
{
	'fsmisc_win',
	function()
		testlib.assert_eq(fsutil.joinpath(unpack(fsutil.splitpath('d:/foo/bar/mod'))), 'd:/foo/bar/mod')
		testlib.assert_eq(fsutil.normalize_dir_sep('foo/blah\\blah.txt'), 'foo/blah/blah.txt')
		testlib.assert_eq(fsutil.normalize_dir_sep('foo/blah/blah.txt'), 'foo/blah/blah.txt')
		-- testlib.assert_eq(fsutil.joinpath(unpack(fsutil.splitpath('d:foo/bar/mod'))), 'd:foo/bar/mod')
	end,
	setup=function()
		spoof_fsutil_ostype('Windows')
	end,
	cleanup=function()
		unspoof_fsutil_ostype()
	end,
},
{
	'fsmisc_lin',
	function()
		testlib.assert_eq(fsutil.normalize_dir_sep('foo/blah\\blah.txt'), 'foo/blah\\blah.txt')
		testlib.assert_eq(fsutil.normalize_dir_sep('foo/blah/blah.txt'), 'foo/blah/blah.txt')
	end,
	setup=function()
		spoof_fsutil_ostype('Linux')
	end,
	cleanup=function()
		unspoof_fsutil_ostype()
	end,
},
{
	'split_ext',
	function()
		local name,ext = fsutil.split_ext('foo')
		assert(name == 'foo' and ext == '')
		name,ext = fsutil.split_ext('.blah')
		assert(name == '.blah' and ext == '')
		name,ext = fsutil.split_ext('.blah.blah')
		assert(name == '.blah' and ext == '.blah')
		name,ext = fsutil.split_ext('bar.txt')
		assert(name == 'bar' and ext == '.txt')
		name,ext = fsutil.split_ext('bar.foo.txt')
		assert(name == 'bar.foo' and ext == '.txt')
		name,ext = fsutil.split_ext('whee.foo/txt')
		assert(name == 'whee.foo/txt' and ext == '')
		name,ext = fsutil.split_ext('whee.foo/bar.txt')
		assert(name == 'whee.foo/bar' and ext == '.txt')
		name,ext = fsutil.split_ext('')
		assert(name == '' and ext == '')
	end,
},
{
	'parse_image_path_cam',
	function()
		testlib.assert_teq(fsutil.parse_image_path_cam('A/DCIM/139___10/IMG_5609.JPG'),{
			dirnum="139",
			dirday="",
			imgnum="5609",
			ext=".JPG",
			pathparts={
				[1]="A/",
				[2]="DCIM",
				[3]="139___10",
				[4]="IMG_5609.JPG",
			},
			dirmonth="10",
			subdir="139___10",
			name="IMG_5609.JPG",
			imgpfx="IMG",
			basename="IMG_5609",
		})
		testlib.assert_teq(fsutil.parse_image_path_cam('A/DCIM/136_1119/CRW_0013.DNG',{string=false}),{
			dirnum="136",
			pathparts={
				[1]="A/",
				[2]="DCIM",
				[3]="136_1119",
				[4]="CRW_0013.DNG",
			},
			dirday="19",
			imgnum="0013",
			basename="CRW_0013",
			imgpfx="CRW",
			subdir="136_1119",
			dirmonth="11",
			name="CRW_0013.DNG",
			ext=".DNG",
			})
		testlib.assert_teq(fsutil.parse_image_path_cam('IMG_5609.JPG',{string=false}),{
			ext=".JPG",
			pathparts={
				[1]="IMG_5609.JPG",
			},
			imgpfx="IMG",
			basename="IMG_5609",
			name="IMG_5609.JPG",
			imgnum="5609",
		})
	end,
},
{
	'find_files',
	function(self)
		local tdir=self._data.tdir
		-- should throw on error
		local r=fsutil.find_files({tdir},{dirs=false,fmatch='%.txt$'},function(t,opts) t:ff_store(t.cur.full) end)
		assert(r)
		local check_files = util.flag_table{fsutil.joinpath(tdir,'empty.txt'),fsutil.joinpath(tdir,'foo.txt')}
		local found = 0
		for i,p in ipairs(r) do
			if check_files[p] then
				found = found+1
			end
			testlib.assert_eq(lfs.attributes(p,'mode'), 'file')
		end
		testlib.assert_eq(found, 2)
		local status,err=pcall(function() return fsutil.find_files({'a_bogus_name_1234'},{dirs=false,fmatch='%.lua$'},function(t,opts) t:ff_store(t.cur.full) end) end)
		assert(not status)
		testlib.assert_eq(err.etype, 'lfs')
	end,
	setup=function(self)
		local tdir=self._data.tdir
		fsutil.mkdir_m(tdir)
		fsutil.writefile_e('',fsutil.joinpath(tdir,'empty.txt'),'wb')
		fsutil.writefile_e('foo',fsutil.joinpath(tdir,'foo.txt'),'wb')
	end,
	cleanup=function(self)
		fsutil.rm_r(self._data.tdir)
	end,
	_data = {
		tdir='chdkptp-test-data'
	},
},
{
	'ustime',
	function()
		local t=os.time()
		local t0=ustime.new(t,600000)
		local t1=ustime.new(t+1,500000)
		testlib.assert_eq(ustime.diff(t1,t0), 900000)
		local t0=ustime.new()
		sys.sleep(100)
		local d = t0:diff()
		-- allow 50 msec (!) fudge, timing is bad on some windows systems
		assert(d > 80000 and d < 150000)
	end,
},
{
	'lbuf',
	function()
		local s="hello world"
		local l=lbuf.new(s)
		testlib.assert_eq(s:len(), l:len())
		testlib.assert_eq(s, l:string())
		testlib.assert_eq(s:sub(0,100), l:string(0,100))
		testlib.assert_eq(l:string(-5), 'world')
		testlib.assert_eq(l:string(1,5), 'hello')
		testlib.assert_eq(l:string(nil,5), 'hello')
		testlib.assert_eq(l:string(100,200), s:sub(100,200))
		testlib.assert_eq(l:byte(0), s:byte(0))
		testlib.assert_eq(l:byte(5), s:byte(5))
		local t1 = {l:byte(-5,100)}
		local t2 = {s:byte(-5,100)}
		testlib.assert_eq(#t1, #t2)
		for i,v in ipairs(t2) do
			testlib.assert_eq(t1[i], t2[i])
		end
		local l2=l:sub()
		testlib.assert_eq(l2:string(), l:string())
		l2 = l:sub(-5)
		testlib.assert_eq(l2:string(), 'world')
		l2 = l:sub(1,5)
		testlib.assert_eq(l2:string(), 'hello')
		l2 = l:sub(100,101)
		testlib.assert_eq(l2:len(), 0)
		testlib.assert_eq(l2:string(), '')
		l=lbuf.new(100)
		testlib.assert_eq(l:len(), 100)
		testlib.assert_eq(l:byte(), 0)
		s=""
		l=lbuf.new(s)
		testlib.assert_eq(l:len(), 0)
		testlib.assert_eq(l:byte(), nil)
		testlib.assert_eq(l:string(), "")
	end,
},
{
	'lbufi',
	function()
		-- TODO not endian aware
		local l=lbuf.new('\001\000\000\000\255\255\255\255')
		testlib.assert_eq(l:get_i32(), 1)
		testlib.assert_eq(l:get_i16(), 1)
		testlib.assert_eq(l:get_i8(), 1)
		testlib.assert_eq(l:get_i32(10), nil)
		testlib.assert_eq(l:get_i32(5), nil)
		testlib.assert_eq(l:get_i16(4), -1)
		testlib.assert_eq(l:get_i32(4,10), -1)
		testlib.assert_eq(l:get_u32(), 1)
		testlib.assert_eq(l:get_u16(), 1)
		testlib.assert_eq(l:get_i32(4), -1)
		testlib.assert_eq(l:get_u8(4), 0xFF)
		testlib.assert_eq(l:get_i8(4), -1)
		testlib.assert_eq(l:get_u32(4), 0xFFFFFFFF)
		testlib.assert_eq(l:get_u32(1), 0xFF000000)
		testlib.assert_eq(l:get_u16(3), 0xFF00)
		local t={l:get_i32(0,100)}
		testlib.assert_eq(#t, 2)
		testlib.assert_eq(t[1], 1)
		testlib.assert_eq(t[2], -1)
		local l=lbuf.new('\001\000\000\000\000\255\255\255\255')
		testlib.assert_eq(l:get_i32(1), 0x000000)
		local t={l:get_u32(0,3)}
		testlib.assert_eq(#t, 2)
		testlib.assert_eq(t[1], 1)
		testlib.assert_eq(t[2], 0xFFFFFF00)
		local l=lbuf.new(string.rep('\001',256))
		local t={l:get_u32(4,-1)}
		testlib.assert_eq(#t, 63)
		local l=lbuf.new(8)
		l:set_u32(0,0xFEEDBABE,0xDEADBEEF)
		local t={l:get_u32(0,2)}
		testlib.assert_eq(#t, 2)
		testlib.assert_eq(t[1], 0xFEEDBABE)
		testlib.assert_eq(t[2], 0xDEADBEEF)
		local t={l:get_u16(0,4)}
		testlib.assert_eq(t[1], 0xBABE)
		testlib.assert_eq(t[2], 0xFEED)
		testlib.assert_eq(t[3], 0xBEEF)
		testlib.assert_eq(t[4], 0xDEAD)
		l:set_i16(0,-1)
		l:set_u16(2,0xDEAD)
		local t={l:get_u16(0,2)}
		testlib.assert_eq(t[1], 0xFFFF)
		testlib.assert_eq(t[2], 0xDEAD)
		local l=lbuf.new(5)
		l:set_i32(0,-1,42)
		local t={l:get_i32(0,2)}
		testlib.assert_eq(#t, 1)
		testlib.assert_eq(t[1], -1)
		local l=lbuf.new(16)
		testlib.assert_eq(l:fill("a"), 16)
		testlib.assert_eq(l:get_u8(), string.byte('a'))
		local l2=lbuf.new(4)
		testlib.assert_eq(l2:fill("hello world"), 4)
		testlib.assert_eq(l:fill(l2,100,1), 0)
		testlib.assert_eq(l:fill(l2,1,2), 8)
		testlib.assert_eq(l:string(2,9), "hellhell")
		testlib.assert_eq(l:string(), "ahellhellaaaaaaa")
		testlib.assert_eq(l:fill(l2,14,20), 2)
	end,
},
{
	'lbufutil',
	function()
		local lbu=require'lbufutil'
		local b=lbu.wrap(lbuf.new('\001\000\000\000\255\255\255\255hello world\000\002\000\000\000'))
		b:bind_i32('first')
		b:bind_i32('second')
		b:bind_u32('second_u',4)
		b:bind_sz('str',12)
		b:bind_rw_i32('last')
		testlib.assert_eq(b.first, 1)
		testlib.assert_eq(b.second, -1)
		testlib.assert_eq(b.second_u, 0xFFFFFFFF)
		testlib.assert_eq(b.str, "hello world")
		testlib.assert_eq(b.last, 2)
		b.last = 3
		testlib.assert_eq(b.last, 3)
		b:bind_seek('set',0)
		b:bind_i32('s1')
		testlib.assert_eq(b.s1, 1)
		testlib.assert_eq(b:bind_seek(), 4) -- return current pos
		testlib.assert_eq(b:bind_seek(4), 8) -- cur +4
		testlib.assert_eq(b:bind_seek('end'), b._lb:len()) -- length
		testlib.assert_eq(b:bind_seek('end',-4), b._lb:len()-4)
		b:bind_seek('set',0)
		b:bind_i8('i8_1')
		testlib.assert_eq(b.i8_1, 1)
		b:bind_seek('set',4)
		b:bind_i8('i8_2')
		testlib.assert_eq(b.i8_2, -1)
		b:bind_u8('u8_1')
		testlib.assert_eq(b.u8_1, 0xFF)
	end,
},
{
	'lbufutil_desc',
	function()
		local lbu=require'lbufutil'
		local l=lbuf.new('\001\000\000\000\255\255\255\255hello world\000\002\000\000\000')
		testlib.assert_eq(lbu.desc_extract(l,'u8'),1)
		testlib.assert_eq(lbu.desc_extract(l,{'u8'}),1)
		testlib.assert_teq(lbu.desc_extract(l,{'u8',4}),{1,0,0,0})
		testlib.assert_teq(lbu.desc_extract(l,{'u8',4},{offset=2}),{0,0,255,255})
		testlib.assert_teq(lbu.desc_extract(l,{
			{'field1','u16'},
			{'field2','u16'},
		},{offset=2}),{field1=0,field2=65535})
		testlib.assert_teq(lbu.desc_extract(l,{
			{'field1','u32'},
			{'field2','i32'},
			-- array of 3 struct
			{'afield',{
				{
					{'c1','u8'},
					{'c2','u8'},
					{'c3','u8'},
				},3}
			},
			-- array of 4 u8
			{'a2',{'u8',4}},
		}),{
			field1=1,
			field2=-1,
			afield={
				{
					c1=string.byte('h'),
					c2=string.byte('e'),
					c3=string.byte('l'),
				},
				{
					c1=string.byte('l'),
					c2=string.byte('o'),
					c3=string.byte(' '),
				},
				{
					c1=string.byte('w'),
					c2=string.byte('o'),
					c3=string.byte('r'),
				},

			},
			a2={
				string.byte('l'),
				string.byte('d'),
				0,
				2,
			}
		})
		testlib.assert_teq(lbu.desc_extract(l,{
			{'field1','u8'},
			{'field2','i32',_align=4},
		}),{field1=1,field2=-1})
		testlib.assert_thrown(function() lbu.desc_extract(l,1) end,{etype='bad_arg',msg_match='expected string or'})
		testlib.assert_thrown(function() lbu.desc_extract(l,{}) end,{etype='bad_arg',msg_match='expected at least 1'})
		testlib.assert_thrown(function() lbu.desc_extract(l,'bogus') end,{etype='bad_arg',msg_match='unexpected type'})
		testlib.assert_thrown(function() lbu.desc_extract(l,{'u63'}) end,{etype='bad_arg',msg_match='unexpected size'})
		testlib.assert_thrown(function() lbu.desc_extract(l,{'u8',3,10}) end,{etype='bad_arg',msg_match='expected exactly 2 fields in array field_desc'})
		testlib.assert_thrown(function() lbu.desc_extract(l,{{'field','u8',10}}) end,{etype='bad_arg',msg_match='expected exactly 2 fields in struct_member'})
		testlib.assert_thrown(function() lbu.desc_extract(l,{false,'u8',10}) end,{etype='bad_arg',msg_match='malformed field_desc'})
		-- TODO desc_text, more complicated nesting
	end,
},
{
	'lbufutil_file',
	function(self)
		local lbu=require'lbufutil'
		local testfile=self._data.testfile
		local b=lbu.loadfile(testfile)
		testlib.assert_eq(b:string(), 'hello world')
		b=lbu.loadfile(testfile,6)
		testlib.assert_eq(b:string(), 'world')
		b=lbu.loadfile(testfile,0,5)
		testlib.assert_eq(b:string(), 'hello')
		b=lbu.loadfile(testfile,6,2)
		testlib.assert_eq(b:string(), 'wo')
		b=lbu.loadfile(testfile,10,1)
		testlib.assert_eq(b:string(), 'd')
		local err
		b,err=lbu.loadfile(testfile,11)
		assert((b==false) and (err=='offset >= file size'))
		b,err=lbu.loadfile(testfile,10,3)
		assert((b==false) and (err=='offset + len > file size'))
	end,
	setup=function(self)
		local testfile=self._data.testfile
		fsutil.mkdir_parent(testfile)
		fsutil.writefile_e('hello world',testfile,'wb')
	end,
	cleanup=function(self)
		fsutil.rm_r(self._data.testdir)
	end,
	_data={
		testdir='chdkptp-test-data',
		testfile='chdkptp-test-data/lbuftest.dat',
	},
},
{
	'lbuff',
	function(self)
		local testfile=self._data.testfile
		local l=lbuf.new('hello world')
		local f=io.open(testfile,'wb')
		l:fwrite(f)
		f:close()
		local l2=lbuf.new(l:len())
		f=io.open(testfile,'rb')
		l2:fread(f)
		f:close()
		testlib.assert_eq(l:string(), l2:string())
		f=io.open(testfile,'wb')
		l:fwrite(f,6)
		f:close()
		f=io.open(testfile,'rb')
		l2:fread(f,0,5)
		f:close()
		testlib.assert_eq(l2:string(), 'world world')
		f=io.open(testfile,'wb')
		l:fwrite(f,6,2)
		f:close()
		f=io.open(testfile,'rb')
		l2:fread(f,9,2)
		f:close()
		testlib.assert_eq(l2:string(), 'world worwo')
	end,
	setup=function(self)
		local testfile=self._data.testfile
		fsutil.mkdir_parent(testfile)
	end,
	cleanup=function(self)
		fsutil.rm_r(self._data.testdir)
	end,
	_data={
		testdir='chdkptp-test-data',
		testfile='chdkptp-test-data/lbuftest.dat',
	},
},
{
	'compare',
	function()
		assert(util.compare_values_subset({1,2,3},{1}))
		assert(util.compare_values_subset({1},{1,2,3})==false)
		local t1={1,2,3,t={a='a',b='b',c='c'}}
		local t2=util.extend_table({},t1)
		assert(util.compare_values(t1,t2))
		assert(util.compare_values(true,true))
		assert(util.compare_values(true,1)==false)
		-- TODO test error conditions
	end,
},
{
	'serialize',
	function()
	local s="this \n is '\" a test"
	local t1={1,2,3,{aa='bb'},[6]=6,t={a='a',['1b']='b',c='c'},s=s}
		testlib.assert_teq(t1, util.unserialize(util.serialize(t1)))
		testlib.assert_eq(s, util.unserialize(util.serialize(s)))
		testlib.assert_eq(true, util.unserialize(util.serialize(true)))
		testlib.assert_eq(nil, util.unserialize(util.serialize(nil)))
		testlib.assert_eq(util.serialize({foo='vfoo'},{pretty=false,bracket_keys=false}), '{foo="vfoo"}')
		testlib.assert_eq(util.serialize({foo='vfoo'},{pretty=false,bracket_keys=true}), '{["foo"]="vfoo"}')
		testlib.assert_eq(util.serialize({1,'two',3,key='value'},{pretty=false,bracket_keys=false}), '{1,"two",3,key="value"}')
		testlib.assert_teq(util.unserialize(util.serialize({-1.4,-1.5,-1.6,1.4,1.5,1.6,0xFFFFFFFF})),{-1,-2,-2,1,2,2,0xFFFFFFFF})
		-- TODO test error conditions
	end,
},
{
	'round',
	function()
		testlib.assert_eq(util.round(0), 0)
		testlib.assert_eq(util.round(0.4), 0)
		testlib.assert_eq(util.round(-0.4), 0)
		testlib.assert_eq(util.round(0.5), 1)
		testlib.assert_eq(util.round(-0.5), -1)
		testlib.assert_eq(util.round(1.6), 2)
		testlib.assert_eq(util.round(-1.6), -2)
	end,
},
{
	'extend_table',
	function()
		local tsub={ka='a',kb='b','one','two'}
		local t={1,2,3,tsub=tsub}
		testlib.assert_teq(util.extend_table({},t),t)
		assert(util.compare_values_subset(util.extend_table({'a','b','c','d'},t),t))
		testlib.assert_teq(util.extend_table({},t,{deep=true}),t)
		testlib.assert_teq(util.extend_table({},t,{deep=true,keys={3,'tsub'}}),{[3]=3,tsub=tsub})
		testlib.assert_teq(util.extend_table({},t,{keys={1,2}}),{1,2})
		testlib.assert_teq(util.extend_table({},t,{keys={1,2,'tsub'}}),{1,2,tsub=tsub})
		assert(not util.compare_values(util.extend_table({},t,{keys={1,2,'tsub'}}),t))
		testlib.assert_teq(util.extend_table({a='a'},t,{keys={1,2,'a'}}),{1,2,a='a'})
		testlib.assert_teq(util.extend_table_multi(
			{a='a',b='A'},{{b='b',c='B',t={ka='b',kc='c'}},{c='c',t=tsub}}),
			{a='a',b='b',c='c',t=tsub})
		testlib.assert_teq(util.extend_table_multi(
			{a='a',b='A'},{{b='b',c='B',t={ka='b',kc='c'}},{c='c',t=tsub}},{deep=true}),
			{a='a',b='b',c='c',t={ka='a',kb='b',kc='c','one','two'}})
		testlib.assert_teq(util.extend_table({},tsub,{iter=util.pairs_string_keys}),
			{ka='a',kb='b'})
	end,
},
{
	'flip_table',
	function()
		testlib.assert_teq(util.flip_table({}),{})
		testlib.assert_teq(util.flip_table({'a','b','c'}),{a=1,b=2,c=3})
		local t=util.flip_table{'a','b','c',foo='bar',dup='c',d=1}
		-- undefined which key is kept for dupes
		assert(t.c == 'dup' or t.c == 3)
		t.c=nil
		testlib.assert_teq(t,{'d',a=1,b=2,bar='foo'})
	end,
},
{
	'table_path',
	function()
		local t={'foo','bar',sub={'one','two',subsub={x='y'},a='b'},one=1}
		testlib.assert_eq(util.table_path_get(t,'bogus'), nil)
		testlib.assert_eq(util.table_path_get(t,'bogus','subbogus'), nil)
		testlib.assert_eq(util.table_path_get(t,1), 'foo')
		testlib.assert_eq(util.table_path_get(t,'sub',2), 'two')
		testlib.assert_eq(util.table_path_get(t,'sub','subsub','x'), 'y')
		testlib.assert_eq(util.table_pathstr_get(t,'sub.subsub.x'), 'y')
		testlib.assert_teq(util.table_path_get(t,'sub'),{'one','two',subsub={x='y'},a='b'})
		local t={{k='b'},{k='a'},{k='c'}}
		util.table_path_sort(t,{'k'})
		testlib.assert_teq(t,{{k='a'},{k='b'},{k='c'}})
		util.table_path_sort(t,{'k'},'des')
		testlib.assert_teq(t,{{k='c'},{k='b'},{k='a'}})
	end,
},
{
	'table_misc',
	function()
		testlib.assert_eq(util.table_amean{1,2,3,4,5,6,7,8,9}, 5)
		testlib.assert_teq(util.table_stats{1,2},{
			min=1,
			sum=3,
			sd=0.5,
			max=2,
			mean=1.5
		})
		assert(util.in_table({'foo','bar'},'foo'))
		assert(not util.in_table({'foo','bar'},'boo'))
		assert(util.in_table({'foo',bar='mod'},'mod'))
		assert(not util.in_table({bar='mod'},'bar'))
	end,
},
{
	'bit_util',
	function()
		local b=util.bit_unpack(0)
		testlib.assert_eq(#b, 31)
		testlib.assert_eq(b[0], 0)
		testlib.assert_eq(b[1], 0)
		testlib.assert_eq(b[31], 0)
		testlib.assert_eq(util.bit_packu(b), 0)
		local b=util.bit_unpack(0x80000000)
		testlib.assert_eq(b[0], 0)
		testlib.assert_eq(b[31], 1)
		testlib.assert_eq(util.bit_packu(b), 0x80000000)
		testlib.assert_eq(util.bit_packu(util.bit_unpack(15,2)), 7)
		testlib.assert_eq(util.bit_packstr(util.bit_unpackstr('hello world')), 'hello world')
		local v=util.bit_packu({[0]=1,0,1})
		testlib.assert_eq(v, 5)
		local v=util.bit_packstr({[0]=1,0,0,0,1,1})
		testlib.assert_eq(v, '1')
		local b=util.bit_unpackstr('hello world')
		local b2 = {[0]=1,0,0,0,1,1}
		for i=0,#b2 do
			table.insert(b,b2[i])
		end
		testlib.assert_eq(util.bit_packstr(b), 'hello world1')
	end,
},
{
	'errutil',
	function()
		local last_err_str
		local last_err
		local f=errutil.wrap(function(a,...)
			if a=='error' then
				error('errortext')
			end
			if a=='throw' then
				errlib.throw({etype='test',msg='test msg'})
			end
			if a=='critical' then
				errlib.throw({etype='testcrit',msg='test msg',critical=true})
			end
			return ...
		end,
		{
			output=function(err_str)
				last_err_str=err_str
			end,
			handler=function(err)
				last_err=err
				return errutil.format(err)
			end,
		})
		local t={f('ok',1,'two')}
		assert(util.compare_values(t,{1,'two'}))
		t={f()}
		testlib.assert_eq(#t, 0)
		local t={f('ok',1,nil,3)}
		assert(util.compare_values(t,{[1]=1,[3]=3}))
		local t={f('error',1,2,3)}
		testlib.assert_eq(#t, 0)
		testlib.assert_eq(string.sub(last_err,-9), 'errortext')
		assert(string.find(last_err_str,'stack traceback:'))
		local t={f('throw',1,2,3)}
		testlib.assert_eq(#t, 0)
		testlib.assert_eq(last_err.etype, 'test')
		assert(not string.find(last_err_str,'stack traceback:'))
		local t={f('critical')}
		testlib.assert_eq(#t, 0)
		testlib.assert_eq(last_err.etype, 'testcrit')
		assert(string.find(last_err_str,'stack traceback:'))
	end,
},
{
	'varsubst',
	function()
		local vs=require'varsubst'
		local s={
			fmt=123.4,
			date=os.time{year=2001,month=11,day=10},
		}
		local funcs=util.extend_table({
			fmt=vs.format_state_val('fmt','%.0f'),
			date=vs.format_state_date('date','%Y%m%d_%H%M%S'),
		},vs.string_subst_funcs)
		local subst=vs.new(funcs,s)
		testlib.assert_eq(subst:run('${fmt}'), '123')
		testlib.assert_eq(subst:run('whee${fmt}ee'), 'whee123ee')
		testlib.assert_eq(subst:run('${fmt, %3.2f}'), '123.40')
		testlib.assert_eq(subst:run('${s_format, hello world}'), 'hello world')
		testlib.assert_eq(subst:run('${s_format,hello world %d,${fmt}}'), 'hello world 123')
		testlib.assert_eq(subst:run('${date}'), '20011110_120000')
		testlib.assert_eq(subst:run('${date,%Y}'), '2001')
		testlib.assert_eq(subst:run('${date,whee %H:%M:%S}'), 'whee 12:00:00')
		assert(pcall(function() subst:validate('${s_format,hello world %d,${fmt}}') end))
		testlib.assert_thrown(function() subst:validate('${bogus}') end,{etype='varsubst',msg_match='unknown'})
		testlib.assert_thrown(function() subst:validate('whee${fmt') end,{etype='varsubst',msg_match='unclosed'})
		testlib.assert_thrown(function() subst:validate('whee${fmt ___}') end,{etype='varsubst',msg_match='parse failed'})
		testlib.assert_eq(subst:run('${s_format,0x%x %s,101,good doggos}'), '0x65 good doggos')
		testlib.assert_eq(subst:run('${s_format,}'), '') -- empty string->empty string
		testlib.assert_thrown(function() subst:run('${s_format}') end,{etype='varsubst',msg_match='s_format missing arguments'})
		testlib.assert_eq(subst:run('${s_sub,hello world,-5}'), 'world')
		testlib.assert_thrown(function() subst:run('${s_sub,hello world}') end,{etype='varsubst',msg_match='s_sub expected 2'})
		testlib.assert_thrown(function() subst:run('${s_sub,hello world,bob}') end,{etype='varsubst',msg_match='s_sub expected number'})
		testlib.assert_thrown(function() subst:run('${s_sub,hello world,5,bob}') end,{etype='varsubst',msg_match='s_sub expected number'})
		testlib.assert_eq(subst:run('${s_upper,hi}'), 'HI')
		testlib.assert_eq(subst:run('${s_lower,Bye}'), 'bye')
		testlib.assert_eq(subst:run('${s_reverse,he}'), 'eh')
		testlib.assert_eq(subst:run('${s_rep, he, 2}'), 'hehe')
		testlib.assert_thrown(function() subst:run('${s_rep,hello world}') end,{etype='varsubst',msg_match='s_rep expected 2'})
		testlib.assert_thrown(function() subst:run('${s_rep,hello world,}') end,{etype='varsubst',msg_match='s_rep expected number'})
		testlib.assert_eq(subst:run('${s_match,hello world,.o%s.*}'), 'lo world')
		testlib.assert_eq(subst:run('${s_match,hello world,o.,6}'), 'or')
		testlib.assert_eq(subst:run('${s_match,hello world,(%a+)%s+(%a+)}'), 'helloworld')
		testlib.assert_thrown(function() subst:run('${s_match,hello world,.,bob}') end,{etype='varsubst',msg_match='s_match expected number'})
		testlib.assert_eq(subst:run('${s_gsub,hello world,(%a+)%s+(%a+),%2 %1}'), 'world hello')
		testlib.assert_eq(subst:run('${s_gsub,hello world,l,_,2}'), 'he__o world')
		testlib.assert_thrown(function() subst:run('${s_gsub,hello world,one,two,three,four}') end,{etype='varsubst',msg_match='s_gsub expected 3'})
		assert(pcall(function() subst:validate('${s_gsub,${s_sub,${s_upper,${s_format,hello world %d,${fmt}}},${s_sub,${fmt},1,1},${s_sub,${fmt},-1}},$,L}') end))
		testlib.assert_eq(subst:run('${s_gsub,${s_sub,${s_upper,${s_format,hello world %d,${fmt}}},${s_sub,${fmt},1,1},${s_sub,${fmt},-1}},$,L}'), 'HELL')
	end,
},
{
	'dng',
	function(self)
		local infile=self._data.infile
		local outfile=self._data.outfile
		local status,err=cli:execute('dngload '..infile)
		assert(status and err == 'loaded '..infile)
		status,err=cli:execute('dngsave '..outfile)
		assert(status) -- TODO 'wrote' message goes to stdout
		status,err=cli:execute('dngdump -thm='..outfile..'.ppm  -tfmt=ppm -raw='..outfile..'.pgm  -rfmt=8pgm')
		assert(status)
		testlib.assert_eq(lfs.attributes(outfile,'mode'), 'file')
		testlib.assert_eq(lfs.attributes(outfile..'.ppm','mode'), 'file')
		testlib.assert_eq(lfs.attributes(outfile..'.pgm','mode'), 'file')
		status,err=cli:execute('dnglistpixels -max=0 -out='..outfile..'.bad.txt -fmt=chdk')
		assert(status)
		testlib.assert_eq(lfs.attributes(outfile..'.bad.txt','mode'), 'file')
	end,
	setup=function(self)
		-- test files not checked in, skip if not present
		if not lfs.attributes(self._data.infile) then
			return false
		end
	end,
	cleanup={
		function(self)
			fsutil.remove_e(self._data.outfile)
		end,
		function(self)
			fsutil.remove_e(self._data.outfile..'.ppm')
		end,
		function(self)
			fsutil.remove_e(self._data.outfile..'.pgm')
		end,
		function(self)
			fsutil.remove_e(self._data.outfile..'.bad.txt')
		end,

	},
	_data = {
		infile='test10.dng',
		outfile='dngtest.tmp',
	},
},
{
	'climisc',
	function(self)
		local status,msg=cli:execute('!return 1')
		local tmpfile=self._data.tmpfile
		assert(status and msg=='=1')
		status,msg=cli:execute('!<'..tmpfile)
		assert(status and msg=='=2')
	end,
	setup=function(self)
		self._data.tmpfile=os.tmpname()
		fsutil.writefile_e('return 1+1\n',self._data.tmpfile,'wb')
	end,
	cleanup=function(self)
		fsutil.remove_e(self._data.tmpfile)
	end,
	_data={}
},
{
	'prefs',
	function(self)
		-- test setting values before reg
		prefs._allow_unreg(true)
		testlib.assert_cli_ok('set test_pref=test')
		prefs._allow_unreg(false)
		prefs._add('test_pref','string','test pref','hi')
		testlib.assert_eq(prefs.test_pref, 'test')
		testlib.assert_cli_ok('set -v test_pref',{match='^test_pref=test%s+- string %(default hi%): test pref'})
		prefs._remove('test_pref')
		testlib.assert_cli_error('set test_pref=bye',{match='unknown pref'})
		testlib.assert_thrown(function() prefs.test_pref="byebye" end,{etype='bad_arg',msg_match='unknown pref'})

		testlib.assert_thrown(function() prefs._add() end,{etype='bad_arg',msg_match='pref name must be string'})
		testlib.assert_thrown(function() prefs._add('bogus') end,{etype='bad_arg',msg_match='unknown vtype: nil'})
		testlib.assert_thrown(function() prefs._add('_describe') end,{etype='bad_arg',msg_match='pref name conflicts with method'})
		testlib.assert_thrown(function() prefs.bogus=1 end,{etype='bad_arg',msg_match='unknown pref'})
		testlib.assert_thrown(function() local v=prefs.bogus end,{etype='bad_arg',msg_match='unknown pref'})
		testlib.assert_thrown(function() prefs.cli_shotseq='bogus' end,{etype='bad_arg',msg_match='invalid value'})
		-- non existent
		testlib.assert_cli_error('set bogus',{match='unknown pref'})
		testlib.assert_cli_error('set bogus=1',{match='unknown pref'})
		-- invalid number
		testlib.assert_cli_error('set cli_time=bogus',{match='invalid value'})
		-- invalid custom
		testlib.assert_cli_error('set err_trace=bogus',{match='invalid value'})
		-- non 0/1 for boolean
		testlib.assert_cli_error('set cli_error_exit=2',{match='invalid value'})
		testlib.assert_cli_ok('set cli_shotseq=100')
		testlib.assert_eq(prefs.cli_shotseq,100)
		prefs.cli_shotseq=200
		testlib.assert_cli_ok('set cli_shotseq',{match='^cli_shotseq=200\n$'})
		testlib.assert_cli_ok('set -c cli_shotseq',{match='^set cli_shotseq=200\n$'})
		testlib.assert_cli_ok('set -v cli_shotseq',{match='^cli_shotseq=200%s+- number %(default 1%):'})
	end,
	setup=function(self)
		self._data.cli_shotseq = prefs.cli_shotseq
	end,
	cleanup=function(self)
		prefs.cli_shotseq = self._data.cli_shotseq
		prefs._remove('test_pref')
		prefs._allow_unreg(false)
	end,
	_data={}
},
{
	'cli_nocon',
	function(self)
		local nocon = {match='not connected'}
		local fn = self._data.testfile
		-- check that commands which require connection return expected error
		testlib.assert_cli_error('lua return 1',nocon)
		testlib.assert_cli_error('getm',nocon)
		testlib.assert_cli_error('putm',nocon)
		testlib.assert_cli_error('luar return 1',nocon)
		-- TODO killscript alone gives protocol ver error, this generates warning about crashes
		-- testlib.assert_cli_error('killscript -force',nocon)
		testlib.assert_cli_error('rmem 0x1900 4',nocon)
		testlib.assert_cli_error('upload '..fn,nocon)
		testlib.assert_cli_error('download bogus bogus',nocon)
		testlib.assert_cli_error('imdl',nocon)
		testlib.assert_cli_error('imls',nocon)
		testlib.assert_cli_error('mdl bogus bogus',nocon)
		testlib.assert_cli_error('mup '..fn..' A/',nocon)
		testlib.assert_cli_error('rm bogus',nocon)
		testlib.assert_cli_error('ls',nocon)
		testlib.assert_cli_error('reboot',nocon)
		-- TODO lvmdump returns bad proto
		testlib.assert_cli_error('lvdumpimg -vp',nocon)
		testlib.assert_cli_error('shoot',nocon)
		testlib.assert_cli_error('rs',nocon)
		testlib.assert_cli_error('rsint',nocon)
		testlib.assert_cli_error('rec',nocon)
		testlib.assert_cli_error('play',nocon)
		testlib.assert_cli_error('clock',nocon)
	end,
	setup=function(self)
		-- tests expect not connected error
		if con:is_connected() then
			return false
		end
		self._data.testfile=os.tmpname()
		fsutil.writefile_e('test',self._data.testfile,'wb')
	end,
	cleanup=function(self)
		fsutil.remove_e(self._data.testfile)
	end,
	_data={}
},
{
	'lvdumpimg_nocon',
	function(self)
		testlib.assert_cli_error('lvdumpimg',{match='^nothing selected'})
		testlib.assert_cli_error('lvdumpimg -fps=1 -wait=10 -vp',{match='^specify wait or fps'})
		testlib.assert_cli_error('lvdumpimg -vp -count=all',{match='^count=all'})
		testlib.assert_cli_error('lvdumpimg -bm -count=quack',{match='^invalid count'})
		testlib.assert_cli_error('lvdumpimg -vp -bm -count=-10',{match='^invalid count'})
		testlib.assert_cli_error('lvdumpimg -vp -seek=5',{match='^seek only valid'})
		-- message varies by os
		local fn = self._data.noexist_file
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp')
		local fn = self._data.bogusfile
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp',{match='^unrecognized file'})
		local fn = self._data.testfile
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp=${bogus}',{match='^unknown substitution'})
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp -vpfmt=bogus',{match='^invalid format bogus'})
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp -pipevp',{match='^must specify command'})
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp=cat -pipevp=split',{match='^pipe split only valid'})
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp=cat -pipevp=combine',{match='^pipe combine only valid'})
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp=cat -pipevp=bogus',{match='^invalid pipe'})
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -bm -pipebm=combine ',{match='^pipe combine requires'})
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp=cat -vpfmt=yuv-s-pgm -pipevp=split -bm -pipebm=combine',{match='^pipe combine requires'})
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -bm=cat -pipebm=split ',{match='^pipe split only valid'})
	end,
	setup=function(self)
		-- tests expect not connected error
		if con:is_connected() then
			return false
		end
		-- file to allow checking format check
		self._data.bogusfile=os.tmpname()
		fsutil.writefile_e(('bogus\n'):rep(100),self._data.bogusfile,'wb')

		self._data.testfile=os.tmpname()
		-- minimally valid header for v1.0 lvdump
		fsutil.writefile_e('chlv'..
							'\x08\x00\x00\x00\x01\x00\x00\x00'..
  							'\x00\x00\x00\x00\x68\x90\x0a\x00\x02\x00\x00\x00'..
  							'\x02\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00'..
  							'\x68\x00\x00\x00\x20\x00\x00\x00\x44\x00\x00\x00'..
  							'\x00\x00\x00\x00\x00\x00\x00\x00\x68\x04\x00\x00'..
  							'\xd0\x02\x00\x00\xd0\x02\x00\x00\xe0\x01\x00\x00'..
  							'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'..
  							'\x00\x00\x00\x00\x01\x00\x00\x00',
							self._data.testfile,'wb')

		-- non-existing file
		self._data.noexist_file=os.tmpname()
		-- os.tmpname may create
		if lfs.attributes(self._data.noexist_file) then
			fsutil.remove_e(self._data.noexist_file)
		end
	end,
	cleanup={
		-- failure test cases may leave file handles open, depending where error thrown
		-- handles would normally be collected and closed at exit, but
		-- collect to ensure they can be removed under windows
		function(self)
			collectgarbage('collect')
		end,
		function(self)
			fsutil.remove_e(self._data.bogusfile)
		end,
		function(self)
			fsutil.remove_e(self._data.testfile)
		end,
	},
	_data={}
},
{
	'shoot_common_opts',
	function()
		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='0.1',
		})
		testlib.assert_eq(opts.sd, 100)

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='1mm',
		})
		testlib.assert_eq(opts.sd, 1)

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='1.5m',
		})
		testlib.assert_eq(opts.sd, 1500)

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='1ft',
		})
		testlib.assert_eq(opts.sd, 305)

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='1in',
		})
		testlib.assert_eq(opts.sd, 25)

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='-1ft',
		})
		testlib.assert_eq(opts.sd, -1)

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='-1in',
		})
		testlib.assert_eq(opts.sd, -1)

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='iNf',
		})
		testlib.assert_eq(opts.sd, -1)

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='1bogus',
		})
		testlib.assert_eq(opts, false)
		testlib.assert_eq(status, 'invalid sd units bogus')

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='1/23',
		})
		testlib.assert_eq(opts, false)
		testlib.assert_eq(status, 'invalid sd 1/23')

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='one hundred fathoms',
		})
		testlib.assert_eq(opts, false)
		testlib.assert_eq(status, 'invalid sd one hundred fathoms')
	end,
	setup=function()
		spoof_con({
			is_connected=function()
				return true
			end,
			is_ver_compatible = function(maj,minor)
				return true
			end
		})
	end,
	cleanup=function()
		if con._unspoof() then
			con._unspoof()
		end
	end,
}
}})

m.tests = tests
return m
