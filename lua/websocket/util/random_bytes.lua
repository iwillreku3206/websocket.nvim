--- @param bytes number number of bytes
--- @return number
local function random_bytes(bytes)
  return math.random(0, math.pow(256, bytes) - 1)
end

--- @param bytes number number of bytes
--- @return string
local function random_bytes_as_hex(bytes)
  return string.format("%x", random_bytes(bytes))
end

return {
  random_bytes = random_bytes,
  random_bytes_as_hex = random_bytes_as_hex
}
