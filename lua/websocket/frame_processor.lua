local Websocket = require("websocket.types.websocket")
local WebsocketFrame = require("websocket.types.websocket_frame")

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

    return frame
  end

  if opcode == Opcodes.CONTINUATION then
    self.previous = self.previous .. data
  end
  return false
end
