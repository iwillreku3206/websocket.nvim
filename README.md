# websocket.nvim

🚧 UNDER CONSTRUCTION: To see list of features to be implemented, see [To-Do](#to-do) below

⚠️ UNDER MAJOR REWRITE: (2024-01-04) I am currently rewriting most of this library to support messages longer than the max packet size, SSL/TLS, key checking, header parsing and more. Expect breaking changes soon

A simple-to-use WebSocket client library for Neovim

## Features
* 📨 Supports binary and text messages with high-level API
* 🏓 Supports ping/pong messages
* 🎭 Supports masking

## Usage

```lua
local Websocket = require('websocket').Websocket

local sock = Websocket:new({
    host = "localhost",
    port = "80",
    path = "/"
})

sock:send_text("Hello, WebSocket!")
```

You may also view the `plugin/open_websocket.lua` file for a test example of this library

## To-Do

* SSL Support
* LuaSec Build Script
* Events documentation
* One-time connect and close event handlers
* SHA-256 key checking
* HTTP header parsing
