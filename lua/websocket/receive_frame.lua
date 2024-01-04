local print_bases = require("websocket.util.print_bases")
local Opcode      = require("websocket.types.opcodes")

--- @param client
--- @return WebsocketFrame | nil
local function receive_frame(client)
  -- get values of byte1 and byte2 of frame
  local bytes
  bytes, err = client:receive(2)
  print_bases.print_hex(bytes)

  if err then self:close() end

  local fin = bit.band(bytes:byte(1), 0x80) == 0x80
  local opcode = bit.band(bytes:byte(1), 0x0F)
  local mask = bit.band(bytes:byte(2), 0x80) == 0x80
  local payload_length = bit.band(bytes:byte(2), 0xEF)

  if payload_length == 126 then
    payload_length, err = client:receive(2)
    if err then self:close() end
  elseif payload_length == 127 then
    payload_length, err = client:receive(8)
    if err then self:close() end
  end

  if mask then
    mask, err = client:receive(4)
    if err then self:close() end
  end

  local data = client:receive(payload_length)

  if fin then
    local frame = WebsocketFrame:new({
      fin = fin,
      opcode = opcode,
      mask = mask,
      payload = self.previous .. data,
    })
    self.previous = ""

    if frame.opcode == Opcode.CLOSE then
      self:close()
      return
    elseif frame.opcode == Opcode.PING then
      local pong_frame = WebsocketFrame:new({
            fin = true,
            opcode = Opcode.PONG,
            payload = frame.payload,
            mask = math.random(0, 0xFFFFFFFF)
          }):to_string()
      self.client:send(pong_frame)
      return
    else
      return frame
    end
  end
end

return receive_frame
