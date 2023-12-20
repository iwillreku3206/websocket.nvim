local Opcode = require("websocket.types.opcodes")
local generate_websocket_key = require("websocket.util.websocket_key")
local uv = vim.loop
local WebsocketFrame = require("websocket.types.websocket_frame")
local print_bases = require("websocket.util.print_bases")
local path_separator = require("websocket.util.path_separator")

local function script_path()
  local str = debug.getinfo(2, 'S').source:sub(2)
  str = str:gsub('/', path_separator)
  return str:match('(.*' .. path_separator .. ')')
end

WS_LUAROCKS_ADDED = false

if not WS_LUAROCKS_ADDED then
  package.path = package.path .. ';' .. script_path() .. "rocks/share/lua/5.1/?.lua"
  package.cpath = package.cpath .. ';' .. script_path() .. "rocks/lib/lua/5.1/?.so"
end

--- @class Websocket
--- @field host string
--- @field port number
--- @field path string
--- @field origin string
--- @field key string
--- @field protocols table
--- @field previous string for FIN bit
--- @field previous_opcode number
--- @field client uv_tcp_t | nil
--- @field frame_count number
--- @field on_message (fun(frame: WebsocketFrame))[]
--- @field on_connect (fun())[]
--- @field on_close (fun())[]
local Websocket = {
  -- settings
  host = "",
  port = 0,
  path = "",
  origin = "",
  key = "",
  protocols = {},
  -- state
  frame_count = 0,
  previous = "",
  previous_opcode = Opcode.TEXT,
  client = nil,
  -- callbacks
  on_message = {},
  on_connect = {},
  on_close = {}
}

Websocket.__index = Websocket

--- @class WebsocketOptions
--- @field host string
--- @field port number
--- @field path string
--- @field origin string
--- @field protocols table
--- @field auto_connect boolean

--- @param o WebsocketOptions
--- @return Websocket
function Websocket:new(o)
  --- @type Websocket
  local ws = {}
  setmetatable(ws, self)
  self.__index = self
  ws.host = o.host
  ws.port = o.port
  ws.path = o.path or "/"
  ws.origin = o.origin or ""
  ws.protocols = o.protocols or {}

  ws.key = generate_websocket_key()

  if o.auto_connect then
    ws:connect()
  end
  return ws
end

function Websocket:connect()
  -- get ip address of host
  local addrinfo = uv.getaddrinfo(self.host, nil, nil)

  if not addrinfo or #addrinfo < 1 then
    print("Error getting address info for websocket host: " .. self.host)
    return
  end

  local addr = addrinfo[1].addr

  -- create a TCP client and connect to the host
  local client = uv.new_tcp()

  if not client then
    print("Error creating TCP client for websocket")
    return
  end

  client:connect(addr, self.port, function(error)
    if error then
      print("Error connecting to websocket: " .. error)
      return
    end

    -- construct an HTTP handshake request
    local request = "GET " .. self.path .. " HTTP/1.1\r\n"
    request = request .. "Host: " .. self.host .. "\r\n"
    request = request .. "Upgrade: websocket\r\n"
    request = request .. "Connection: Upgrade\r\n"
    request = request .. "Sec-WebSocket-Key: " .. self.key .. "\r\n"
    request = request .. "Sec-WebSocket-Version: 13\r\n"
    if self.origin ~= "" then
      request = request .. "Origin: " .. self.origin .. "\r\n"
    end
    if #self.protocols > 0 then
      request = request .. "Sec-WebSocket-Protocol: " .. table.concat(self.protocols, ", ") .. "\r\n"
    end
    request = request .. "\r\n"

    -- send the handshake request
    client:write(request, function(handshake_send_error)
      if error then
        print("Error sending websocket handshake: " .. handshake_send_error)
        return
      else
        client:read_start(function(read_error, data)
          if read_error then
            print("Error reading from websocket: " .. read_error)
            return
          end

          -- TODO: parse and return readers
          if data and self.frame_count == 0 then
            local response = data:match("HTTP/1.1 (%d+)")

            if not response or response ~= "101" then
              print("Error: websocket handshake failed")
              return
            end
            self.client = client
            for _, fn in ipairs(self.on_connect) do
              fn()
            end
          end

          if data and self.frame_count > 0 then
            local frame = self:process_frame(data)

            if frame then
              for _, fn in ipairs(self.on_message) do
                fn(frame)
              end
            end
          end

          self.frame_count = self.frame_count + 1
        end)
      end
    end)
  end)
end

--- Send a disconnect message to the peer
function Websocket:disconnect()
  local close_frame = WebsocketFrame:new({
        fin = true,
        opcode = Opcode.CLOSE,
        payload = "",
        mask = math.random(0, 0xFFFFFFFF)
      }):to_string()
  if not self.client then
    print("Error: websocket is not connected")
    return
  end
  self.client:write(close_frame, function(error)
    if error then
      print("Error sending websocket close frame: " .. error)
      return
    end
  end)
end

--- Close the websocket connection
--- For most purposes, use `Websocket:disconnect()` instead
function Websocket:close()
  self.client:close(function(error)
    if error then
      print("Error closing websocket: " .. error)
      return
    end
    for _, fn in ipairs(self.on_close) do
      fn()
    end
  end)
end

local function stub()
end

--- @param fn fun(frame: WebsocketFrame)
--- @return number
function Websocket:add_on_message(fn)
  table.insert(self.on_message, fn)
  return #self.on_message
end

--- @param index number
function Websocket:remove_on_message(index)
  self.on_message[index] = stub
end

--- @param fn fun()
--- @return number
function Websocket:add_on_connect(fn)
  table.insert(self.on_connect, fn)
  return #self.on_close
end

--- @param index number
function Websocket:remove_on_connect(index)
  self.on_connect[index] = stub
end

--- @param fn fun()
--- @return number
function Websocket:add_on_close(fn)
  table.insert(self.on_close, fn)
  return #self.on_close
end

--- @param index number
function Websocket:remove_on_close(index)
  self.on_close[index] = stub
end

---@param data string
---@return false | WebsocketFrame # false if not finished, frame is finished
function Websocket:process_frame(data)
  local index = 1
  local fin = bit.band(data:byte(index), 0x80) == 0x80
  local opcode = bit.band(data:byte(index), 0x0F)

  index = index + 1 --index 2

  --- @type boolean | number
  local mask = bit.band(data:byte(index), 0x80) == 0x80
  local payload_length = bit.band(data:byte(index), 0xEF)

  index = index + 1 --index 3
  if payload_length == 126 then
    payload_length = bit.bor(bit.lshift(data:byte(index), 8), data:byte(index + 1))
    index = index + 2
  elseif payload_length == 127 then
    payload_length = bit.bor(
      bit.lshift(data:byte(index), 56),
      bit.lshift(data:byte(index + 1), 48),
      bit.lshift(data:byte(index + 2), 40),
      bit.lshift(data:byte(index + 3), 32),
      bit.lshift(data:byte(index + 4), 24),
      bit.lshift(data:byte(index + 5), 16),
      bit.lshift(data:byte(index + 6), 8),
      data:byte(index + 7)
    )
    index = index + 8
  end

  if mask then
    mask = bit.bor(
      bit.lshift(data:byte(index), 24),
      bit.lshift(data:byte(index + 1), 16),
      bit.lshift(data:byte(index + 2), 8),
      data:byte(index + 3)
    )
    index = index + 4
  end

  local data_old = "" .. data
  data = data:sub(index)

  if data:len() ~= payload_length then
    print("Error: payload length does not match data length")
    print(data:len() .. " ~= " .. payload_length)
    print(data_old)
    return false
  end

  if fin then
    local frame = WebsocketFrame:new({
      fin = fin,
      opcode = opcode,
      mask = mask,
      payload = self.previous .. data,
    })
    self.previous = ""

    if frame:to_string() ~= data_old then
      print("Error: frame does not match data")
      print_bases.print_hex(data_old)
      print_bases.print_hex(frame:to_string())
      return false
    end

    if frame.opcode == Opcode.CLOSE then
      self:close()
      return false
    end

    if frame.opcode == Opcode.PING then
      local pong_frame = WebsocketFrame:new({
            fin = true,
            opcode = Opcode.PONG,
            payload = frame.payload,
            mask = math.random(0, 0xFFFFFFFF)
          }):to_string()
      self.client:write(pong_frame, function(error)
        if error then
          print("Error sending websocket pong frame: " .. error)
          return
        end
      end)
      return false
    end

    return frame
  end

  if opcode == Opcode.CONTINUATION then
    self.previous = self.previous .. data
  end
  return false
end

function Websocket:send_frame(frame)
  self.client:write(frame:to_string(), function(error)
    if error then
      print("Error sending websocket frame: " .. error)
      return
    end
  end)
end

function Websocket:send_text(text)
  local frame = WebsocketFrame:new({
    fin = true,
    opcode = Opcode.TEXT,
    payload = text,
    mask = math.random(0, 0xFFFFFFFF)
  })
  self:send_frame(frame)
end

function Websocket:send_binary(binary)
  local frame = WebsocketFrame:new({
    fin = true,
    opcode = Opcode.BINARY,
    payload = binary,
    mask = math.random(0, 0xFFFFFFFF)
  })
  self:send_frame(frame)
end

return { Websocket = Websocket, Opcode = Opcode }
