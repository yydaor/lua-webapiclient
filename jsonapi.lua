-- Modified from:
-----------------------------------------------------------------------------
-- JSONRPC4Lua: JSON RPC client calls over http for the Lua language.
-- json.rpc Module.
-- Author: Craig Mason-Jones
-- Homepage: http://json.luaforge.net/
-- Version: 0.9.40
-- This module is released under the MIT License (MIT).
-- Please see LICENCE.txt for details.
--
-- USAGE:
-- This module exposes two functions:
--   proxy( 'url')
--     Returns a proxy object for calling the JSON RPC Service at the given url.
--   call ( 'url', 'method', ...)
--     Calls the JSON RPC server at the given url, invokes the appropriate method, and
--     passes the remaining parameters. Returns the result and the error. If the result is nil, an error
--     should be there (or the system returned a null). If an error is there, the result should be nil.
--
-- REQUIREMENTS:
--  Lua socket 2.0 (http://www.cs.princeton.edu/~diego/professional/luasocket/)
--  json (The JSON4Lua package with which it is bundled)
--  compat-5.1 if using Lua 5.0.
------------------------------------------------------------------

local json = require('json')
local http = require("socket.http")
local https = require "https"
local ltn12 = require('ltn12')
local mime = require("mime")

local metat = { __index = {} }

metat.__index.get_url = function(self, path)
  print("Given path '" .. path .. "'")
  if self.baseurl then
    return self.baseurl .. path
  else
    return path
  end
end

metat.__index.send_request = function(self, verb, path, input)
  local httpResponse, result, code
  local jsonRequest
  if input then
    jsonRequest = json.encode(input)
  end

  -- We use the sophisticated http.request form (with ltn12 sources and sinks) so that
  -- we can set the content-type to text/plain. While this shouldn't strictly-speaking be true,
  -- it seems a good idea (Xavante won't work w/out a content-type header, although a patch
  -- is needed to Xavante to make it work with text/plain)

  local resultChunks = {}

  local request = {
    sink = ltn12.sink.table(resultChunks),
    method = verb,
    url = self:get_url(path)
  }
  if request.url:sub(1, 6) == "https" then
    request.create = https.create
  end

  if jsonRequest then
    request.headers = { ['content-type']='text/plain', ['content-length']=string.len(jsonRequest) }
    request.source = ltn12.source.string(jsonRequest)
  end

  -- Debugging prints
  if type(request.headers) == "table" then
    print("Headers:")
    for k, v in pairs(request.headers) do
      print(k, v)
    end
  end

  httpResponse, code = http.request(request)

  httpResponse = table.concat(resultChunks)
  -- Check the http response code
  print("HTTP code: " .. code)
  if (code<200 or code > 299) then
    error("HTTP ERROR: " .. code .. "\n" .. httpResponse)
  end
  -- And decode the httpResponse and check the JSON RPC result code
  result = json.decode( httpResponse )
  if result.result then
    return code, result.result
  else
    return code, nil, result.error
  end
end

local index_to_request = function(self, verb)
  return function(self, ...)
    return self:send_request(verb:upper(), ...)
  end
end

setmetatable(metat.__index, {
  __index = index_to_request
})

local function createProxy(url)
  return setmetatable({["baseurl"] = url}, metat)
end

local universal = setmetatable({}, metat)

return {
  ["createProxy"] = createProxy,
  ["universal"] = universal
}
