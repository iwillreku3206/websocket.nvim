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
      auto_connect = true
    })
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    sock:add_on_message(function(frame)
      vim.schedule(function()
        local pos = vim.api.nvim_win_get_cursor(0)
        if vim.api.nvim_get_current_line() == "" then
          pos[1] = pos[1] - 1
        end
        if frame.opcode == Opcodes.TEXT then
          local no_newline, _ = string.gsub(frame.payload, "\n", "")
          vim.api.nvim_buf_set_lines(buf, pos[1], pos[1], false, { no_newline })
        end
        if frame.opcode == Opcodes.BINARY then
          vim.api.nvim_buf_set_lines(buf, pos[1], pos[1], false, { print_bases.fmt_hex(frame.payload) })
        end
      end)
    end)
  end,
  { nargs = "+" })
