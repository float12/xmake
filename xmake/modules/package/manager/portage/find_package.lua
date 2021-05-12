--!A cross-platform build utility based on Lua
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- Copyright (C) 2015-present, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        find_package.lua
--

-- imports
import("core.base.option")
import("lib.detect.find_file")
import("lib.detect.find_tool")
import("package.manager.pkgconfig.find_package", {alias = "find_package_from_pkgconfig"})

-- find package from the system directories
--
-- @param name  the package name
-- @param opt   the options, e.g. {verbose = true, version = "1.12.x")
--
function main(name, opt)

    -- init options
    opt = opt or {}

    -- for msys2/mingw? mingw-w64-[i686|x86_64]-xxx
    if opt.plat == "mingw" then
        name = "mingw64-runtime" -- there is only one package for mingw
    end

    -- get package files list
    local file_path = "/var/db/pkg/*/" .. name .. "-*/"
    local file = find_file("CONTENTS", file_path)

    -- if the file couldn't be found, then the package isn't installed
    if not file then
        return
    end

    local file_contents = io.readfile(file)

    -- create a table for the list
    local list_table = {}

    -- split entries based on newlines
    local entries = file_contents:split("\n")

    -- iterate over the table created by split()
    for _, entry in pairs(entries) do
        -- the file path is the second element after being delimited by spaces
        local split_entry = entry:split(" ")[2]
        table.insert(list_table, split_entry)
    end

    -- create a string out of list_table called list
    local list = table.concat(list_table, "\n")

    -- parse package files list
    local pkgconfig_dir = nil
    local pkgconfig_name = nil
    local linkdirs = {}
    local has_includes = false
    for _, line in ipairs(list:split('\n', {plain = true})) do
        line = line:trim():split('%s+')[1]
        if not pkgconfig_dir and line:find("/pkgconfig/", 1, true) and line:endswith(".pc") then
            pkgconfig_dir  = path.directory(line)
            pkgconfig_name = path.basename(line)
        end
        if line:endswith(".so") or line:endswith(".a") or line:endswith(".lib") then
            table.insert(linkdirs, path.directory(line))
        elseif line:find("/include/", 1, true) and (line:endswith(".h") or line:endswith(".hpp")) then
            has_includes = true
        end
    end

    -- find package
    local result = nil
    if pkgconfig_dir then
        linkdirs = table.unique(linkdirs)
        includedirs = table.unique(includedirs)
        result = find_package_from_pkgconfig(pkgconfig_name or name, {configdirs = pkgconfig_dir, linkdirs = linkdirs})
        if not result and has_includes then
            -- header only and hidden /usr/include? we need only return empty {}
            result = {}
        end
    end
    return result
end