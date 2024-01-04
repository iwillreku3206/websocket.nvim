local Opcode                 = require("websocket.types.opcodes")
local generate_websocket_key = require("websocket.util.websocket_key").generate_websocket_key
local verify_websocket_key   = require("websocket.util.websocket_key").verify_websocket_key
local parse_headers          = require("websocket.util.parse_headers")
local WebsocketFrame         = require("websocket.types.websocket_frame")
local print_bases            = require("websocket.util.print_bases")
local path_separator         = require("websocket.util.path_separator")
local random_bytes           = require("websocket.util.random_bytes")

local uv                     = vim.loop
if vim.uv then
  uv = vim.uv
end

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

local socket = require("socket")
local ssl = require("ssl")

--- @alias OnMessageCallback fun(frame: WebsocketFrame)
--- @alias OnConnectCallback fun(): table<string, string>
--- @alias OnCloseCallback fun(reason: string | nil)

--- @class Websocket
--- @field host string
--- @field port number
--- @field path string
--- @field origin string
--- @field key string
--- @field protocols table
--- @field tls boolean
--- @field previous string For FIN bit
--- @field previous_opcode number
--- @field connected boolean Connected with handshake
--- @field client uv_tcp_t | nil
--- @field thread luv_thread_t | nil
--- @field write_pipe uv_pipe_t | nil
--- @field read_pipe uv_pipe_t | nil
--- @field on_message OnMessageCallback[]
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
  tls = false,
  -- state
  connected = false,
  previous = "",
  previous_opcode = Opcode.TEXT,
  client = nil,
  thread = nil,
  write_pipe = nil,
  read_pipe = nil,
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
--- @field tls boolean

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
  ws.tls = o.tls or false

  ws.key = generate_websocket_key()

  if o.auto_connect then
    ws:connect()
  end
  return ws
end

--- @param callback OnConnectCallback | nil
--- @return boolean success Returns true if connection is successful
function Websocket:connect(callback)
  -- get ip address of host
  local addrinfo = uv.getaddrinfo(self.host, nil, nil)

  if not addrinfo or #addrinfo < 1 then
    print("Error getting address info for websocket host: " .. self.host)
    return false
  end

  local addr = addrinfo[1].addr


  self.connected = true
  self.client = client

  -- create pipes for inter-thread communication
  local fds = uv.pipe({ nonblock = true }, { nonblock = true })

  self.write_pipe = uv.new_pipe()
  self.read_pipe = uv.new_pipe()

  if self.write_pipe == nil or self.read_pipe == nil then
    print("Unable to create pipes")
    self:close()
  end

  local open_write = self.write_pipe:open(fds.write)
  local open_read = self.read_pipe:open(fds.read)

  if not open_read or not open_write then
    print("Unable to open pipes")
    self:close()
  end

  local pipe_bind, err1, err2 = pipe:bind(pipe_name)

  ---@param write_pipe uv_pipe_t
  self.thread = uv.new_thread(function(client, write_pipe)
    local receive_frame = require("websocket.receive_frame")

    print(write_pipe:is_writable())
    while write_pipe:is_writable() do
      local frame = receive_frame(client)
      print(frame)
      if frame then
        write_pipe:send(frame)
      end
    end
    client:close()
  end, client, self.write_pipe)

  if self.thread == nil then
    print("Unable to initialize thread")
    self:close()
  end

  pipe:read_start(function(err, data)
    if err then
      print("Unable to read from pipe")
      self:close()
    end
    for _, fn in ipairs(self.on_message) do
      fn(data)
    end
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
  self.client:close()
  self.read_pipe:close()
  self.write_pipe:close()
  for _, fn in ipairs(self.on_close) do
    fn()
  end
  self.connected = false
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
