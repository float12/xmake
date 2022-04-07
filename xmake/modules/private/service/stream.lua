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
-- @file        stream.lua
--

-- imports
import("core.base.object")
import("core.base.bytes")

-- define module
local stream = stream or object()

-- init stream
function stream:init(sock)
    self._SOCK = sock
    self._RCACHE = bytes(8192)
    self._RCACHE_SIZE = 0
    self._RECVBUFF = bytes(65536)
end

-- send bytes
function stream:send(data)
end

-- send table
function stream:send_table(tbl)
end

-- send string
function stream:send_string(str)
end

-- recv the given bytes
function stream:recv(buff, size)
    assert(size <= buff:size())

    -- read data from cache first
    local buffsize = 0
    local cache = self._RCACHE
    local cache_size = self._RCACHE_SIZE
    local cache_maxn = cache:size()
    if size <= cache_size then
        buff:copy(cache, 1, size)
        cache_size = cache_size - size
        self._RCACHE_SIZE = cache_size
        return buff:slice(1, size)
    elseif cache_size > 0 then
        buff:copy(cache, 1, cache_size)
        buffsize = cache_size
        cache_size = 0
    end
    assert(cache_size == 0)

    -- recv data from socket
    local real = 0
    local data = nil
    local wait = false
    local errors = nil
    while buffsize < size do
        real, data = sock:recv(cache)
        if real > 0 then
            -- append data to buffer
            local leftsize = size - buffsize
            if real < leftsize then
                buff:copy2(buffsize, data)
                buffsize = buffsize + real
            else
                buff:copy2(buffsize, data, 1, leftsize)
                buffsize = buffsize + leftsize

                -- move left cache to head
                cache_size = real - leftsize
                if cache_size > 0 then
                    cache:move(leftsize, cache_size)
                end
                self._RCACHE_SIZE = cache_size
                return buff:slice(1, buffsize)
            end
            wait = false
        elseif real == 0 and not wait then
            if sock:wait(socket.EV_RECV, -1) == socket.EV_RECV then
                wait = true
            else
                break
            end
        else
            break
        end
    end
end

-- recv u16be
function stream:recv_u16be()
    local data = self:recv(self._RECVBUFF, 2)
    if data then
        return data:u16be()
    end
end

-- recv table
function stream:recv_table()
end

-- recv string
function stream:recv_string()
    local size = self:recv_u16be()
    if size then
        local data = self:recv(self._RECVBUFF, size)
        if data then
            return data:str()
        end
    end
end

function main(sock)
    local instance = stream()
    instance:init(sock)
    return instance
end