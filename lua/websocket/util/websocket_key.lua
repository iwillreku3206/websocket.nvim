local base64 = require("websocket.util.base64")
local sha = require("websocket.util.sha2")

local function generate_websocket_key()
  -- generate a random 16-byte string
  local key = ""
  for _ = 1, 16 do
    key = key .. string.char(math.random(32, 127))
  end

  -- base64 encode the string
  return base64.encode(key)
end


--- From "DarkWiiPlayer" on StackOverFlow.
--- @param hex string Hex string
--- @see https://stackoverflow.com/questions/65476909/lua-string-to-hex-and-hex-to-string-formulas
--- @return string
local function hexdecode(hex)
  return (hex:gsub("%x%x", function(digits) return string.char(tonumber(digits, 16)) end))
end

--- @param key string Original key (base64)
--- @param hash string Hashed key (from header, base64)
local function verify_websocket_key(key, hash)
  local hash_b64 = base64.encode(hexdecode(sha.sha1(key .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")))

  return hash == hash_b64
end

return {
  generate_websocket_key = generate_websocket_key,
  verify_websocket_key = verify_websocket_key
}
