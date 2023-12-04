local Websocket = require("websocket.types.websocket")

--- @param fn fun(frame: WebsocketFrame) -> number
function Websocket:add_on_message(fn)
  table.insert(self.on_message, fn)
  return #self.on_message
end

local function stub()
end

--- @param index number
function Websocket:remove_on_message(index)
  self.on_message[index] = stub
end
