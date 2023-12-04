local Opcode = require("websocket.types.opcodes")

--- @class Websocket
--- @field host string
--- @field port number
--- @field path string
--- @field origin string
--- @field key string
--- @field protocols table
--- @field previous string for FIN bit
--- @field frame_count number
--- @field on_message (fun(frame: WebsocketFrame))[]

local Websocket = {
  -- settings
  host = "",
  port = 0,
  path = "",
  origin = "",
  key = "",
  protocols = {},
  -- state
  frame_count = 0,
  previous = "",
  previous_opcode = Opcode.TEXT,
  -- callbacks
  on_message = {}
}

return Websocket
