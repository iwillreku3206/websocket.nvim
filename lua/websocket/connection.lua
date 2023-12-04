local generate_websocket_key = require("websocket.util.websocket_key")
local Websocket = require("websocket.types.websocket")
local uv = vim.loop

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
  end)

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
  client:write(request, function(error)
    if error then
      print("Error sending websocket handshake: " .. error)
      return
    end
  end)

  client:read_start(function(error, data)
    if error then
      print("Error reading from websocket: " .. error)
      return
    end

    if data and self.frame_count == 0 then
      local response = data:match("HTTP/1.1 (%d+)")

      if not response or response ~= "101" then
        print("Error: websocket handshake failed")
        return
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

return Websocket
