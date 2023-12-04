local Opcode = require("websocket.types.opcodes")
local Websocket = require("websocket.types.websocket")

require("websocket.frame_processor")
require("websocket.connection")
require("websocket.events")

return { Websocket = Websocket, Opcode = Opcode }
