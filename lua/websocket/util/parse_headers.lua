--- @param http_header_string string
--- @return table<string, string> headers
local function parse_headers(http_header_string)
  local headers = {}

  local i = 0
  for line in http_header_string:gmatch("(.-)\n") do
    if i == 0 then
      i = i + 1
      goto continue
    end

    i = i + 1

    line = line .. ": "

    local match = line:gmatch("(.-): ")
    local key = match()
    local value = match()

    if key and value then
      headers[key] = value
    end

    ::continue::
  end
  return headers
end

return parse_headers
