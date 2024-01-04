local Opcode = require("websocket.types.opcodes")

--- @class WebsocketFrame
--- @field opcode Opcode
--- @field mask false | number
--- @field payload string
WebsocketFrame = {
  fin = true,
  opcode = Opcode.TEXT,
  mask = false,
  payload = "",
}

--- @class WebsocketFrameOptions
--- @field fin boolean
--- @field opcode Opcode
--- @field mask boolean | number
--- @field payload_masked boolean Set to `true` if the data being provided by the payload is already masked
--- @field payload string

--- @param options WebsocketFrameOptions
--- @return WebsocketFrame
function WebsocketFrame:new(options)
  local frame = {}
  setmetatable(frame, self)
  self.__index = self

  frame.fin = options.fin or true
  frame.opcode = options.opcode or Opcode.TEXT
  frame.mask = options.mask or false
  frame.payload = options.payload or ""

  if options.payload_masked and self.mask ~= false then
    local masked_payload = ""
    for i = 1, self.payload:len() do
      local j = (i - 1) % 4
      masked_payload = masked_payload .. string.char(bit.bxor(self.payload:byte(i),
            bit.band(bit.rshift(bit.lshift(self.mask, 8 * j), 24), 0xff)))
    end
    frame.payload = masked_payload
  end

  return frame
end

--- @return string
function WebsocketFrame:to_string()
  local header = ""
  -- 1st and 2nd byte
  local first_byte = 0x00
  if self.fin then
    first_byte = bit.bor(first_byte, 0x80)
  end
  first_byte = bit.bor(first_byte, self.opcode)

  header = header .. string.char(first_byte)

  -- 3rd and 4th byte
  local second_byte = 0x00
  if self.mask then
    second_byte = bit.bor(second_byte, 0x80)
  end

  -- payload length
  if self.payload:len() < 126 then
    second_byte = bit.bor(second_byte, self.payload:len())
    header = header .. string.char(second_byte)
  elseif self.payload:len() < 65536 then
    second_byte = bit.bor(second_byte, 126)
    header = header .. string.char(second_byte)
    header = header .. string.char(bit.rshift(self.payload:len(), 8))
    header = header .. string.char(bit.band(self.payload:len(), 0xFF))
  else
    second_byte = bit.bor(second_byte, 127)
    header = header .. string.char(second_byte)
    header = header .. string.char(bit.rshift(self.payload:len(), 56))
    header = header .. string.char(bit.band(bit.rshift(self.payload:len(), 48), 0xFF))
    header = header .. string.char(bit.band(bit.rshift(self.payload:len(), 40), 0xFF))
    header = header .. string.char(bit.band(bit.rshift(self.payload:len(), 32), 0xFF))
    header = header .. string.char(bit.band(bit.rshift(self.payload:len(), 24), 0xFF))
    header = header .. string.char(bit.band(bit.rshift(self.payload:len(), 16), 0xFF))
    header = header .. string.char(bit.band(bit.rshift(self.payload:len(), 8), 0xFF))
    header = header .. string.char(bit.band(self.payload:len(), 0xFF))
  end

  -- mask
  if self.mask and self.mask ~= true then
    header = header .. string.char(bit.rshift(self.mask, 24))
    header = header .. string.char(bit.band(bit.rshift(self.mask, 16), 0xFF))
    header = header .. string.char(bit.band(bit.rshift(self.mask, 8), 0xFF))
    header = header .. string.char(bit.band(self.mask, 0xFF))
  end

  if self.mask then
    local masked_payload = ""
    for i = 1, self.payload:len() do
      local j = (i - 1) % 4
      masked_payload = masked_payload .. string.char(bit.bxor(self.payload:byte(i),
            bit.band(bit.rshift(bit.lshift(self.mask, 8 * j), 24), 0xff)))
    end
    return header .. masked_payload
  end

  return header .. self.payload
end

return WebsocketFrame
