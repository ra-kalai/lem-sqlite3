#!/usr/bin/env lem
--
-- This file is part of lem-sqlite3.
-- Copyright 2012 Emil Renner Berthing
--
-- lem-sqlite3 is free software: you can redistribute it and/or
-- modify it under the terms of the GNU General Public License as
-- published by the Free Software Foundation, either version 3 of
-- the License, or (at your option) any later version.
--
-- lem-sqlite3 is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with lem-sqlite3.  If not, see <http://www.gnu.org/licenses/>.
--

package.path = '?.lua;' .. package.path
package.cpath = '?.so;' .. package.cpath

local format = string.format
local write = io.write
local tostring = tostring

local function printf(...)
	return write(format(...))
end

local function prettyprint(t)
	local widths, columns = {}, #t[1]
	for i = 1, columns do
		widths[i] = 0
	end

	for i = 1, #t do
		local row = t[i]
		for j = 1, columns do
			local value = row[j]
			local typ = type(value)
			if typ == 'nil' then
				value = 'NULL'
			elseif typ == 'string' then
				value = format("'%s'", value)
			else
				value = tostring(value)
			end

			local len = #value
			if len > widths[j] then widths[j] = #value end
			row[j] = value
		end
	end

	for i = 1, #widths do
		widths[i] = '%-' .. tostring(widths[i] + 1) .. 's';
	end

	for i = 1, #t do
		local row = t[i]
		for j = 1, columns do
			write(format(widths[j], row[j] or 'NULL'))
		end
		write('\n')
	end
end

local utils  = require 'lem.utils'
local io     = require 'lem.io'
local sqlite = require 'lem.sqlite3.queued'

local exit = false
utils.spawn(function()
	local write, yield = io.write, utils.yield
	local sleeper = utils.newsleeper()

	repeat
		write('.')
		sleeper:sleep(0.01)
	until exit
end)

for i,v in pairs(sqlite.bindkind) do
	print(i, v)
end

local db, err = sqlite.open('test.db', sqlite.READWRITE)

assert(db:exec[[
DROP TABLE IF EXISTS test;
CREATE TABLE test (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	ji int,
	jf float,
	payload BLOB
);
]])

assert(db:exec[[BEGIN TRANSACTION;]])
local stmt = assert(db:prepare('\z
	INSERT INTO test (ji, jf, payload) \z
	VALUES (@ji, @jf, @payload);'))
local queued = type(stmt) ~= 'userdata'

for i=1, 1000 do 
	local raw = stmt:get()
	local v = { ji = {sqlite.bindkind.INT, 10 },
				  		jf = {sqlite.bindkind.INT, 10 },
							payload={sqlite.bindkind.BLOB, "woot" .. i .. " \0 " .. i}}

	raw:bind(v)
	assert(assert(raw:step()) == true, 'hmm..')

	stmt:put()
end

assert(stmt:finalize())

assert(db:exec[[COMMIT TRANSACTION;]])

print()
exit = true

-- vim: set ts=2 sw=2 noet:
