local base64 = require("websocket.util.base64")

local function generate_websocket_key()
  -- generate a random 16-byte string
  local key = ""
  for _ = 1, 16 do
    key = key .. string.char(math.random(32, 127))
  end

  -- base64 encode the string
  return base64.encode(key)
end

return generate_websocket_key
