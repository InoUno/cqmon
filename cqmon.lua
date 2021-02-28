chat = require('chat')
files = require('files')
packets = require('packets')

_addon = _addon or {}
_addon.name = 'ConquestMon'
_addon.author = 'InoUno'
_addon.version = '1.0.0'
_addon.command = 'cqmon'

cqmon = cqmon or {}

cqmon.mobs = {}

function cqmon.getBits(value, start, length)
  return bit.band(bit.rshift(value, start), bit.lshift(1, length)-1)
end


function cqmon.print(message)
  if message then
    windower.add_to_chat(7, '[ConquestMon] ' .. message)
  end
end

function cqmon.requestConquestMessage()
  packets.inject(packets.new('outgoing', 0x5A))
end

-----------------
-- Mob handlers
-----------------

-- Handle mob death
function cqmon.handleDeath(mobId)
  cqmon.print('Requesting conquest information')
  cqmon.requestConquestMessage()
end


--------------------
-- Defeat update
--------------------

function cqmon.handleDefeatMessage(data)
  local packet = packets.parse('incoming', data)

  if packet['Message'] == 6 then -- Mob defeated
    cqmon.handleDeath(packet['Target'])
  end
end

function cqmon.handleConquestMessage(data)
  -- local packet = packets.parse('incoming', data)

  -- for i=1, #data do
  --   cqmon.print(i .. ': ' .. data:byte(i))
  -- end

  cqmon.print('Sandy %: ' .. data:byte(1 + 0x86))
  cqmon.print('Bastok %: ' .. data:byte(1 + 0x87))
  cqmon.print('Windy %: ' .. data:byte(1 + 0x88))
  cqmon.print('Beastmen %: ' .. data:byte(1 + 0x94))


  cqmon.print('Sandy unknown: ' .. data:byte(1 + 0x89))
  cqmon.print('Bastok unknown: ' .. data:byte(1 + 0x8A))
  cqmon.print('Windy unknown: ' .. data:byte(1 + 0x8B))

  -- for key, value in pairs(fields) do
  --   cqmon.print(key .. ': ' .. value)
  -- end
  -- for key, value in pairs(packet) do
  --   cqmon.print(key .. ': ' .. value)
  -- end

  -- cqmon.print(packet["San d'Oria region bar"])
  -- cqmon.print(packet["Bastok region bar"])
  -- cqmon.print(packet["Windurst region bar"])
  -- cqmon.print(packet["San d'Oria region bar without beastmen"])
  -- cqmon.print(packet["Bastok region bar without beastmen"])
  -- cqmon.print(packet["Windurst region bar without beastmen"])
  -- cqmon.print(packet["Beastmen region bar"])
end

--------------------
-- Action handler
--------------------

function cqmon.actionHandler(action)
  -- Defeated message
  if action.message == 6 then
    cqmon.processDeath(action['Target'])
    return
  end
end


-------------------
-- Chunk handler
-------------------

function cqmon.chunkHandler(id, data, modified, injected, blocked)
  if id == 0x029 then -- Check
    cqmon.handleDefeatMessage(data)
  elseif id == 0x05E then
    cqmon.handleConquestMessage(data)
  end
end



-----------------------
-- File utility
-----------------------

-- Handles opening, or creating, a file object. Returns it.
--------------------------------------------------
function cqmon.fileOpen(path)
  local file = {
    stream = files.new(path, true),
    locked = false,
    scheduled = false,
    buffer = ''
  }
  return file
end

-- Handles writing to a file (gently)
--------------------------------------------------
function cqmon.fileAppend(file, text)
  if not file.locked then
    file.buffer = file.buffer .. text
    if not file.scheduled then
      file.scheduled = true
      coroutine.schedule(function() cqmon.fileWrite(file) end, 0.5)
    end
  else
    coroutine.schedule(function() cqmon.fileAppend(file, text) end, 0.1)
  end
end

-- Writes to a file and empties the buffer
--------------------------------------------------
function cqmon.fileWrite(file)
  file.locked = true
  local to_write = file.buffer
  file.buffer = ''
  file.scheduled = false
  file.stream:append(to_write)
  file.locked = false
end

-----------------------
-- Register handlers
-----------------------
windower.register_event('action', cqmon.actionHandler)
windower.register_event('incoming chunk', cqmon.chunkHandler)
windower.register_event('prerender', function()
  for _, mob in pairs(cqmon.mobs) do
    cqmon.calculate(mob)
  end
end)

windower.register_event('addon command', function (command, ...)
	command = command and command:lower()
	if command == 'request' then
    cqmon.requestConquestMessage()
	end
end)