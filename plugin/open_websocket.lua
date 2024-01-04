-- Command that will open a websocket connection to a given host and port.

local Websocket = require "websocket".Websocket
local Opcodes = require "websocket.types.opcodes"
local print_bases = require "websocket.util.print_bases"

vim.api.nvim_create_user_command("OpenWebsocket",
  function(opts)
    local sock = Websocket:new({
      host = opts.fargs[1],
      port = opts.fargs[2],
      path = opts.fargs[3],
      protocols = { "test" },
      origin = "http://localhost",
      auto_connect = false
    })
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    sock:add_on_connect(function()
      TestWS = sock
    end)
    sock:add_on_message(function(frame)
      vim.schedule(function()
        local pos = vim.api.nvim_win_get_cursor(0)
        if vim.api.nvim_get_current_line() == "" then
          pos[1] = pos[1] - 1
        end
        if frame.opcode == Opcodes.TEXT then
          local no_newline, _ = string.gsub(frame.payload, "\n", "")
          vim.api.nvim_buf_set_lines(buf, pos[1], pos[1], false, { no_newline })
          if frame.payload:find('disconnect') then
            sock:disconnect()
          end
        end
        if frame.opcode == Opcodes.BINARY then
          vim.api.nvim_buf_set_lines(buf, pos[1], pos[1], false, { print_bases.fmt_hex(frame.payload) })
        end
        if frame.opcode == Opcodes.CLOSE then
          vim.api.nvim_buf_set_lines(buf, pos[1], pos[1], false, { "Remote server disconnected" })
        end
      end)
    end)
    sock:connect()
  end,
  { nargs = "+" })

vim.api.nvim_create_user_command("TestCommand", function()
  local socket = require('socket')
  local sock = socket.tcp()
  print "a"
  sock:settimeout(500)
  print "acc"
  local conn, err = sock:connect("127.0.0.1", 9900)
  print("b" .. vim.json.encode(err))

  self = {
    path = "/",
    host = "localhost",
    key = require("websocket.util.websocket_key")(),
    origin = "",
    protocols = {}
  }
  local request = "GET " .. self.path .. " HTTP/1.1\r\n"
  request = request .. "Host: " .. self.host .. "\r\n"
  request = request .. "Upgrade: websocket\r\n"
  request = request .. "Connection: Upgrade\r\n"
  request = request .. "Sec-WebSocket-Key: " .. self.key .. "\r\n"
  request = request .. "Sec-WebSocket-Version: 13\r\n"
  if self.origin ~= "" then
    request = request .. "Origin: " .. self.origin .. "\r\n"
  end
  if #self.protocols > 0 then
    request = request .. "Sec-WebSocket-Protocol: " .. table.concat(self.protocols, ", ") .. "\r\n"
  end
  request = request .. "\r\n"

  local handshake_request = sock:send(request)
  while true do
    previous, err = sock:receive("*l")
    if p == "" then
      break
    end
  end
end, {})
