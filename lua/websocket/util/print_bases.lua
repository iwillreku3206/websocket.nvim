--- @param data string
--- @returns string
local function fmt_hex(data)
  local hex = ""
  for i = 1, #data do
    hex = hex .. string.format("%02X ", string.byte(data, i))
  end
  return hex
end

--- @param data string
--- @returns string
local function fmt_hex_nospace(data)
  local hex = ""
  for i = 1, #data do
    hex = hex .. string.format("%02X", string.byte(data, i))
  end
  return hex
end

--- @param data string
local function print_hex(data)
  print(fmt_hex(data))
end

return {
  fmt_hex = fmt_hex,
  fmt_hex_nospace = fmt_hex_nospace,
  print_hex = print_hex
}
