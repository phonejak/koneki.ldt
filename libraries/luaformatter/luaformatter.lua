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
	indentation = {},
	reference = {}
}

local INDENT = true

function walker.block.down(node, parent, ...)
  -- Ignore empty node
  if #node == 0 or not parent then
    return
  end
  walker.indentchunk(node, parent)
end

function walker.expr.down(node, parent, ...)
  if walker.indenttable and node.tag == 'Table' and #node > 0 then
  --TODO
  elseif node.tag =='String' then
    local firstline = node.lineinfo.first.line
    local lastline = node.lineinfo.last.line
    for i=firstline+1, lastline do
      walker.linetodepth[i]=false
    end
  end
end

function walker.stat.up(node, ...)
  if walker.formatters[node.tag] then
    walker.formatters[node.tag](node, ...)
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

function walker.indent(startline, startindex, endline, parent)

  -- Indent following lines when current one does not start with first statement
  -- of current block.
  if not walker.source:sub(1,startindex-1):find("[\r\n]%s*$") then
    startline = startline + 1
  end

  -- Nothing interesting to do
  if endline < startline then
    return
  end

  -- Indent block first line
  walker.indentation[startline] = INDENT

  -- Restore indentation
  walker.reference[endline+1] = walker.getfirstline(parent)
end

---
-- Indent all lines of a chunk.
function walker.indentchunk(node, parent)
  -- Get node positions
  local endline = walker.getlastline(node[#node])
  local startline, startindex = walker.getfirstline(node[1])
  walker.indent(startline, startindex, endline, parent)
end

---
-- Indent all lines of an `Index which can be recursive.
function walker.indentindex(node, parent)

  -- Indent left side
  local left, right = unpack(node)
  if left.tag == 'Index' then
  	walker.indentindex(left, parent)
  end
  
  -- Indent right side once
  local startline = walker.getfirstline(right)
  local startindex = right.lineinfo.last.offset
  walker.indent(startline, startindex, walker.getlastline(parent), parent)
end

---
-- Indent all lines of an expression list.
function walker.indentexprlist(node, parent)
  local endline = walker.getlastline(node)
  local startline, startindex = walker.getfirstline(node)
  walker.indent(startline, startindex, endline, parent)
end

function walker.formatters.Forin(node)
  local ids, iterator, _ = unpack(node)
  walker.indentexprlist(ids, node)
  walker.indentexprlist(iterator, node)
end

function walker.formatters.Fornum(node)

  -- Format from variable name to last expressions
  local var, init, limit, range = unpack(node)
  local startline, startindex   = walker.getfirstline(var)

  -- Take range as last expression, when not available limit will do
  local lastexpr = range.tag and range or limit
  walker.indent(startline, startindex, walker.getlastline(lastexpr), node)

end

function walker.formatters.If(node)

  -- Indent only conditions, chunks are already taken care of.
  local nodesize = #node
  for conditionposition=1, nodesize-(nodesize%2), 2 do
    walker.indentexprlist(node[conditionposition], node)
  end

end

function walker.formatters.Invoke(node)

  -- Check if indentation is needed on left side
  local id, str = unpack(node)
  if id.tag == 'Index' then
    -- TODO: All `Index should be indented. This specific call has to move.
    walker.indentindex(id, node)
  end

  -- Regular case: only indent after left side
  local startline = walker.getfirstline(id)
  local startindex = id.lineinfo.last.offset
  walker.indent(startline, startindex, walker.getlastline(str), node)
end

function walker.formatters.Local(node)
  local lhs, exprs = unpack(node)
  if #exprs == 0 then
    -- Regular handling
    walker.indentexprlist(lhs, node)
  else
    -- Indent LHS and expressions like a single chunk
    local endline = walker.getlastline(exprs)
    local startline, startindex = walker.getfirstline(lhs)
    walker.indent(startline, startindex, endline, node)

    -- In this block indent expressions one more
    walker.indentexprlist(exprs, node)
  end
end
walker.formatters.Set = walker.formatters.Local

function walker.formatters.Repeat(node)
  local _, expr = unpack(node)
  walker.indentexprlist(expr, node)
end

function walker.formatters.Return(node, parent)
  if #node > 0 then
    walker.indentchunk(node, parent)
  end
end

function walker.formatters.While(node)
  local expr, _ = unpack(node)
  walker.indentexprlist(expr, node)
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
  local ast = mlc:src_to_ast(source)
  walker.linetodepth = { 0 }
  walker.indenttable = indenttable
  walker.source = source
  walker.nodecache = {}
  walk.block(walker, ast)

  -- Built depth table
  local currentdepth = 0
  local depthtable = {}
  for line=1, walker.getlastline(ast[#ast]) do
    -- Restore depth
    if walker.reference[line] then
      currentdepth = depthtable[walker.reference[line]]
    end
    -- Indent
    if walker.indentation[line] then
      currentdepth = currentdepth + 1
    end
    depthtable[line]= currentdepth
  end
  return depthtable
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
