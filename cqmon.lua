chat = require('chat')
files = require('files')
packets = require('packets')
texts = require('texts')
config = require('config')

_addon = _addon or {}
_addon.name = 'ConquestMon'
_addon.author = 'InoUno'
_addon.version = '2.0.0'
_addon.command = 'cqmon'

cqmon = cqmon or {}
cqmon.data = cqmon.data or {}
cqmon.settings = cqmon.settings or {}

cqmon.defaults = {}
cqmon.defaults.infobox = T{
  pos = T{
    x = windower.get_windower_settings().x_res - 240,
    y = windower.get_windower_settings().y_res * 1/4,
  },
  padding = 2,
  text = {
    size  = 10,
    font  = 'Consolas',
    alpha = 255,
    red   = 255,
    green = 255,
    blue  = 255,
  },
  bg = {
    red   = 30,
    green = 30,
    blue  = 60,
    alpha = 230,
  },
}

cqmon.onkill = cqmon.onkill or true
cqmon.auto = cqmon.auto or nil

function cqmon.startAutoQuery(delay)
  cqmon.print(string.format("Starting auto query with delay of about %d seconds.", delay))
  cqmon.auto = coroutine.schedule(function ()
    while true do
      cqmon.requestConquestMessage()
      coroutine.sleep(delay + math.random() * 2)
    end
  end, delay)
end

function cqmon.endAutoQuery()
  if cqmon.auto then
    cqmon.print("Stopping auto query.")
    coroutine.close(cqmon.auto)
    cqmon.auto = nil
  end
end

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
  if cqmon.onkill then
    cqmon.requestConquestMessage()
  end
  cqmon.data.kills = (cqmon.data.kills or 0) + 1
  cqmon.infobox.kills = cqmon.data.kills
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
  local percentages = {
    sandoria = data:byte(1 + 0x86),
    bastok = data:byte(1 + 0x87),
    windurst = data:byte(1 + 0x88),
    beastmen = data:byte(1 + 0x94),
  }

  local unknown = {
    sandoria = data:byte(1 + 0x89),
    bastok = data:byte(1 + 0x8A),
    windurst = data:byte(1 + 0x8B),
  }

  cqmon.data.lastQuery = os.time()
  cqmon.infobox.sandoriaPct = percentages.sandoria
  cqmon.infobox.bastokPct = percentages.bastok
  cqmon.infobox.windurstPct = percentages.windurst
  cqmon.infobox.beastmenPct = percentages.beastmen

  if cqmon.data.lastBeastmenPct ~= percentages.beastmen then
    cqmon.print(string.format('Beastmen percentage has changed: %d to %d', cqmon.data.lastBeastmenPct, percentages.beastmen))
    cqmon.data.lastBeastmenPct = percentages.beastmen
    cqmon.data.lastBeastmenChange = os.time()
  end
end

--------------------
-- Build UI
--------------------

function cqmon.buildInfoBox()
  if not cqmon.infobox then
    local lines = {
      "San d'Oria:     ${sandoriaPct|%d}%",
      "Bastok:         ${bastokPct|%d}%",
      "Windurst:       ${windurstPct|%d}%",
      "Beastmen:       ${beastmenPct|%d}%",
      "---------------------",
      "Kills:          ${kills|%d}",
      "Last query:     ${sinceLastQuery|%d}s",
    }
    cqmon.infobox = texts.new(table.concat(lines, '\n'), cqmon.defaults.infobox)
    cqmon.infobox.kills = 0
    cqmon.infobox.sandoriaPct = 0
    cqmon.infobox.bastokPct = 0
    cqmon.infobox.windurstPct = 0
    cqmon.infobox.beastmenPct = 0
    cqmon.infobox.sinceLastQuery = 0
    cqmon.infobox:show()
  end
end

function cqmon.prerender()
  if cqmon.infobox then
    cqmon.infobox.sinceLastQuery = cqmon.data.lastQuery and (os.time() - cqmon.data.lastQuery) or 0
  end
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
windower.register_event('prerender', cqmon.prerender)

windower.register_event('addon command', function (command, arg1)
	command = command and command:lower()
	if command == 'request' or command == 'r' then
    cqmon.requestConquestMessage()
  elseif command == 'auto' or command == 'a' then
    if cqmon.auto then
      cqmon.endAutoQuery()
    else
      cqmon.startAutoQuery(tonumber(arg1) or 20)
    end
  elseif command == 'onkill' or command == 'k' then
    cqmon.onkill = not cqmon.onkill
    cqmon.print('Auto query on kill is now: ' .. (cqmon.onkill and 'ON' or 'OFF'))
  end
end)

windower.register_event('load', function ()
  cqmon.settings = config.load(config.defaults)
  cqmon.buildInfoBox()
end)

windower.register_event('unload', function ()
  config.save(cqmon.settings)
end)
