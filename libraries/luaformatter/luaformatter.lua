--------------------------------------------------------------------------------
-- Copyright (c) 2011, 2013 Sierra Wireless and others.
-- All rights reserved. This program and the accompanying materials
-- are made available under the terms of the Eclipse Public License v1.0
-- which accompanies this distribution, and is available at
-- http://www.eclipse.org/legal/epl-v10.html
--
-- Contributors:
--     Sierra Wireless - initial API and implementation
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Uses Metalua capabilities to indent code and provide source code offset
-- semantic depth
--
-- @module luaformatter
--------------------------------------------------------------------------------
local M = {}
require 'metalua.package'
local mlc = require 'metalua.compiler'.new()
local math = require 'math'

--
-- Define AST walker
--
local walker = {
	block = {},
	depth = 0,     -- Current depth while walking
	expr  = {},
	stat  = {},
	linetodepth = { 0 },
	indenttable = true,
	source = "",
	formatters = {},
}

---
-- @type DEPTH
-- @field DIVE
-- @field LAST
-- @field STILL
local DEPTH = {
  DIVE  = '>',
  LAST  = '.',
  STILL = '|',
}

---
-- Generates an empty node, its lineinfo field is composed of
-- * first: lineinfo.first of first child node
-- * last:  lineinfo.last of last child node
--
-- Useful for dealing with `Table and chunks.
-- @return #table
local function makefakenode(node)
	local firstli = node[1].lineinfo.first
	return {
		tag = 'FakeNode',
		lineinfo = {
			first = firstli.comments and firstli.comments.first or firstli,
			last  = node[#node].lineinfo.last
		}
	}
end

function walker.block.down(node, ...)
  -- Ignore empty node
  if #node == 0 then
    return
  end
  walker.processchunk(node)
end

function walker.expr.down(node, parent, ...)
	if walker.indenttable and node.tag == 'Table' and #node > 0 then
		local fakenode = makefakenode(node)
		walker.processchunk(node)
	elseif node.tag =='String' then
		local firstline = node.lineinfo.first.line
		local lastline = node.lineinfo.last.line
		for i=firstline+1, lastline do
			walker.linetodepth[i]=false
		end
	end
end

function walker.stat.up(node)
  if walker.formatters[node.tag] then
    walker.formatters[node.tag](node)
  end
end

---
-- Comment adjusted first line and first offset of a node.
--
-- @return #int, #int
function walker.getfirstline(node)
  -- Consider preceding comments as part of current chunk
  -- WARNING: This is NOT the default in Metalua
  local first, offset
  local offsets = node.lineinfo
  if offsets.first.comments then
    first = offsets.first.comments.lineinfo.first.line
    offset = offsets.first.comments.lineinfo.first.offset
  else
    -- Regular node
    first = offsets.first.line
    offset = offsets.first.offset
  end
  return first, offset
end

---
-- Last line of a node.
--
-- @return #int
function walker.getlastline(node)
  return node.lineinfo.last.line
end

---
-- Initialize all lines of chunk to DEPTH.STILL, so indentation will not move.
function walker.processchunk(node)
  local startline, startindex = walker.getfirstline(node[1])
  local endline = walker.getlastline(node[#node])
  for line=startline, endline do
    if not walker.linetodepth[line] then
      walker.linetodepth[line] = DEPTH.STILL
    end
  end
end

---
-- Indent all lines of a chunk, must be called after #walker.processchunk
function walker.indentchunk(node)

  -- Get node position
  local startline, startindex = walker.getfirstline(node)
  local endline = walker.getlastline(node[#node])

  if endline <= startline then
    -- Nothing interesting to do
    return
  end

  -- Indent all lines following the first one
  walker.linetodepth[startline] = DEPTH.DIVE
  -- Restore previous depth
  walker.linetodepth[endline] = startline
end

function walker.formatters.Do(node)
  if #node > 0 then
    walker.indentchunk(node)
  end
end
--------------------------------------------------------------------------------
-- Calculate all indent level
-- @param Source code to analyze
-- @return #table {linenumber = indentationlevel}
-- @usage local depth = format.indentLevel("local var")
--------------------------------------------------------------------------------
local function getindentlevel(source, indenttable)

  if not loadstring(source, 'CheckingFormatterSource') then
    return
  end

  -- Walk through AST to build linetodepth
  local walk = require 'metalua.walk'
  walker.linetodepth = { 0 }
  walker.indenttable = indenttable
  walker.source = source
  walker.nodecache = {}
  walk.block(walker, mlc:src_to_ast(source))
  local t = {}
  local currentdepth = 0
  --  table.print(walker.linetodepth, 1)

  for line, depth in ipairs(walker.linetodepth) do
    t[line] = currentdepth
    if depth == DEPTH.LAST then
      currentdepth = currentdepth - 1
    elseif depth == DEPTH.DIVE then
      currentdepth = currentdepth + 1
    elseif type(depth) == 'number' and depth > 0 then
      currentdepth = t[depth]
    end
  end

  --  table.print(t, 1)
  return t
end

--------------------------------------------------------------------------------
-- Trim white spaces before and after given string
--
-- @usage local trimmedstr = trim('          foo')
-- @param #string string to trim
-- @return #string string trimmed
--------------------------------------------------------------------------------
local function trim(string)
	local pattern = "^(%s*)(.*)"
	local _, strip =  string:match(pattern)
	if not strip then return string end
	local restrip
	_, restrip = strip:reverse():match(pattern)
	return restrip and restrip:reverse() or strip
end

--------------------------------------------------------------------------------
-- Indent Lua Source Code.
--
-- @function [parent=#luaformatter] indentcode
-- @param source source code to format
-- @param delimiter line delimiter to use
-- @param indenttable true if you want to indent in table
-- @param ...
-- @return #string formatted code
-- @usage indentCode('local var', '\n', true, '\t',)
-- @usage indentCode('local var', '\n', true, --[[tabulationSize]]4, --[[indentationSize]]2)
--------------------------------------------------------------------------------
function M.indentcode(source, delimiter,indenttable, ...)
	--
	-- Create function which will generate indentation
	--
	local tabulation
	if select('#', ...) > 1 then
		local tabSize = select(1, ...)
		local indentationSize = select(2, ...)
		-- When tabulation size and indentation size is given, tabulation is
		-- composed of tabulation and spaces
		tabulation = function(depth)
			local range = depth * indentationSize
			local tabCount = math.floor(range / tabSize)
			local spaceCount = range % tabSize
			local tab = '\t'
			local space = ' '
			return tab:rep(tabCount) .. space:rep(spaceCount)
		end
	else
		local char = select(1, ...)
		-- When tabulation character is given, this character will be duplicated
		-- according to length
		tabulation = function (depth) return char:rep(depth) end
	end

	-- Delimiter position table
	-- Initialization represent string start offset
	local delimiterLength = delimiter:len()
	local positions = {1-delimiterLength}

	--
	-- Seek for delimiters
	--
	local i = 1
	local delimiterPosition = nil
	repeat
		delimiterPosition = source:find(delimiter, i, true)
		if delimiterPosition then
			positions[#positions + 1] = delimiterPosition
			i = delimiterPosition + 1
		end
	until not delimiterPosition
	-- No need for indentation, while no delimiter has been found
	if #positions < 2 then
		return source
	end

	-- calculate indentation
	local linetodepth = getindentlevel(source,indenttable)

	-- Concatenate string with right indentation
	local indented = {}
	for  position=1, #positions do
		-- Extract source code line
		local offset = positions[position]
		-- Get the interval between two positions
		local rawline
		if positions[position + 1] then
			rawline = source:sub(offset + delimiterLength, positions[position + 1] -1)
		else
			-- From current position to end of line
			rawline = source:sub(offset + delimiterLength)
		end

		-- Trim white spaces
		local indentcount = linetodepth[position]
		if not indentcount then
			indented[#indented+1] = rawline
		else
			local line = trim(rawline)
			-- Append right indentation
			-- Indent only when there is code on the line
			if line:len() > 0 then
				-- Compute next real depth related offset
				-- As is offset is pointing a white space before first statement
				-- of block,
				-- We will work with parent node depth
				indented[#indented+1] = tabulation( indentcount )
				-- Append timmed source code
				indented[#indented+1] = line
			end
		end
		-- Append carriage return
		-- While on last character append carriage return only if at end of
		-- original source
		local endofline = source:sub(source:len()-delimiterLength, source:len())
		if position < #positions or endofline == delimiter then
			indented[#indented+1] = delimiter
		end
	end

	return table.concat(indented)
end

return M
