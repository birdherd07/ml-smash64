-- This template lives at `.../Lua/.template.lua`.

--Notes: Leave empty players at the end, ex. if you have 2 players put them in p1 and p2 slots, not p1 and p3 or p1 and p4. This messes up memory locations for some reason.
--Script will work for versus mode stock or timed, 1-4 players
---------------------------------------------------------------------------------
-- observed memory locations

-- 4 byte DWORD unsigned Big Endian
--versus mode
local p1_dmg_loc = 0x0A4D74
local p2_dmg_loc = 0x0A4DE8
local p1_death_loc = 0x0A4D38
local p2_death_loc = 0x0A4D3C

--byte training mode 
local p1_tra_loc = 0x1909D4 -- 131607, 1909bf, 190a37, 190a3b, 190a4b, 284db7
local p2_tra_loc = 0x284db4 --131604, 1909bc, 190a34, 190a38, 190a48, 284db4
local dmg_offset = 76
--loc : 2638392
--dmg: 2641332

-- from the ui? not sure what object this is part of
--minutes
local timer_1 = 0x1317C8
local timer_2 = 0x1317C9
--seconds
local timer_3 = 0x1317CA
local timer_4 = 0x1317CB

--start of the player objects
local player_loc = 0x26D7D8

-- offsets. coordinates relative to middle of stage
local x_offset = 120 --diff of 42F0 ? depends on character
local y_offset = 4

local player_offset = 0xB50 -- size of player object?
local char_offset = 11
local anim_offset = 38
local jump_offset = 328

local match_offset = 3
local time_offset = 6
local stock_offset = 7
local stage_offset = 1

-- start of game object
local game_loc = 0xA4D08
local type_offset = 34

-- n64 memory sizes
local bus_max = 0x80000000;
local readable_max = 0x800000;

---------------------------------------------------------------------------------
-- The following tables are for reference / human readability

-- not complete; luigi is 4? other unlockables > 9
local characters = {
	[0] = "Mario",
	[1] = "Fox",
	[2] = "Donkey Kong",
	[3] = "Samus",
	[5] = "Link",
	[6] = "Yoshi",
	[8] = "Kirby",
	[9] = "Pikachu"
}

--not complete; unlockable stage + classic mode stages > 7
-- dimensions: left edge x, right edge x, lowest grounded y point on stage.
local stages = {
	[0] = {name = "Peach Castle",},
	[1] = {name = "Sector Z",},
	[2] = {name = "Kong Jungle",},
	[3] = {name = "Planet Zebes",},
	[4] = {name = "Hyrule Castle",},
	[5] = {name = "Yoshi's Island", right_limit = 1983, left_limit = -1989, bottom_limit = -390},
	[6] = {name = "Dream Land"},
	[7] = {name = "Saffron City"}
}

-- VERY not complete; note different stages of the same animation have different numbers, ex. starting to jump vs. finishing a jump
-- Some animations are unique to certain characters
local animations = {
	[10] = "Idle",
	[20] = "Starting Jump",
	[27] = "Ending Jump",
	[31] = "Landing",
	[212] = "Up Air Attack"
}

-- This value does not differentiate between team and non-team versions of these modes
local match_types = {
	[0] = "undefined",
	[1] = "time",
	[2] = "stock"
}

-- Ignore nonexistent players with type 2
local player_types = {
	[0] = "Human",
	[1] = "CPU",
	[2] = "Absent"
}

---------------------------------------------------------------------------------
-- onscreen display info for debugging

--local txt_color = 0xFF000000 --black
local txt_color = 0xFFFFFFFF --white
local txt_buf = 9

---------------------------------------------------------------------------------
-- Table information updated each frame for ML

local game = {
	match_type = 0,
	time_limit = 0, --seconds. in stock battle, defaults to whatever last timer was, usually 180
	timer = 0, --counts down to 0
	stock_limit = 0, --in timed battle, defaults to whatever the last stock number was, usually 3
	stage = 0
}

--ignore any players of type 2
-- note between matches all players get garbage values, and during matches absent players can get garbage
local players = {
	{p = 1, type = 0, dmg = 0, deaths = 0, x = 0, y = 0, char = 0, anim = 0, jumps = 0},
	{p = 2, type = 0, dmg = 0, deaths = 0, x = 0, y = 0, char = 0, anim = 0, jumps = 0},
	{p = 3, type = 0, dmg = 0, deaths = 0, x = 0, y = 0, char = 0, anim = 0, jumps = 0},
	{p = 4, type = 0, dmg = 0, deaths = 0, x = 0, y = 0, char = 0, anim = 0, jumps = 0}
}

---------------------------------------------------------------------------------
-- Game stuff

local function update_time()
	local mins = (mainmemory.readbyte(timer_1) * 10) + mainmemory.readbyte(timer_2)
	local secs = (mainmemory.readbyte(timer_3) * 10) + mainmemory.readbyte(timer_4)
	game.timer = mins * 60 + secs
end

local function update_game_info()
	game.match_type = mainmemory.readbyte(game_loc + match_offset)
	game.time_limit = mainmemory.readbyte(game_loc + time_offset) * 60
	game.stock_limit = mainmemory.readbyte(game_loc + stock_offset) + 1 -- this value always reads as the actual stock number - 1 for some reason
	game.stage = mainmemory.readbyte(game_loc + stage_offset)
	-- Player type is stored here instead of player objects
	local game_players = game_loc + type_offset
	for i = 0, 3 do
		players[i+1].type = mainmemory.readbyte(game_players + 116 * i)
	end

	if game.match_type == 1 then
		update_time()
	end
end

--- Player specific stuff
--- 
local function in_memory(loc)
	-- values can go out of range while a battle is not occurring
	return loc <= readable_max and loc >=0
end

local function update_coords(player_start, playerno)
	-- truncating floats since the scale is large
	local temp_x = mainmemory.read_u32_be(player_start + x_offset) - bus_max
	if in_memory(temp_x) then
		local unrounded_x = mainmemory.readfloat(temp_x, true)
		players[playerno].x = math.floor(unrounded_x)
	end
	if in_memory(temp_x) then
		local unrounded_y = mainmemory.readfloat(temp_x + y_offset, true)
		players[playerno].y = math.floor(unrounded_y)
	end
end

--wip: fix these for all players
local function update_dmg()
	players[1].dmg = mainmemory.read_u32_be(p1_dmg_loc)
	players[2].dmg = mainmemory.read_u32_be(p2_dmg_loc)
end

local function update_deaths()
	players[1].deaths = mainmemory.read_u32_be(p1_death_loc)
	players[2].deaths = mainmemory.read_u32_be(p2_death_loc)
end

local function update_players()
	for i = 0, 3 do
		if players[i+1].type ~= 2 then --dont bother with absent characters
			local playern = player_loc + i * player_offset;
			players[i+1].char = mainmemory.readbyte(playern + char_offset)
			players[i+1].anim = mainmemory.read_u16_be(playern + anim_offset)
			players[i+1].jumps = mainmemory.readbyte(playern + jump_offset)
			update_coords(playern, i+1)
			update_dmg()
			update_deaths()
		end
	end
end

-- Debug / testing display

local function draw_vals()
	local i = 1
	local x_offset = txt_buf
	for index, player_vals in ipairs(players) do
		-- column 2
		if index == 3 then
			i = 1
			x_offset = 235
		end
		-- print player name first (unordered table)
		gui.drawText(x_offset, txt_buf * i, "P"..player_vals.p, txt_color, 5)
		i = i + 1
		-- print rest
		for k, v in pairs(player_vals) do
			if k ~= 'p' then
				gui.drawText(x_offset, txt_buf * i, k..": "..v, txt_color, 5)
				i = i + 1
			end
		end
		--print game info
		if index == 2 then
			gui.drawText(x_offset, txt_buf * i, "Game", txt_color, 5)
			i = i + 1
			for k, v in pairs(game) do
				gui.drawText(x_offset, txt_buf * i, k..": "..v, txt_color, 5)
				i = i + 1
			end
		end
	end
end

---------------------------------------------------------------------------------
-- main loop 

while true do
	update_game_info()
	update_players()

	draw_vals()

	emu.frameadvance();
end
