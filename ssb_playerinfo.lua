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
local p1_anim = 0x28425F --byte us be
----------------------------

--start of the player objects
local player_loc = 0x26D7D8

-- from the ui? not sure what object this is part of
--minutes
local timer_1 = 0x1317C8
local timer_2 = 0x1317C9
--seconds
local timer_3 = 0x1317CA
local timer_4 = 0x1317CB

-- floats. coordinates relative to middle of stage
local x_offset = 120
local y_offset = 4

local p2_x_loc = 0x2F8BA4
local p1_x_loc = 0x2F48B4
--diff of 42F0 ? depends on character

-- offsets
local player_offset = 0xB50 -- size of player object?
local char_offset = 11
local anim_offset = 38

local match_offset = 3
local time_offset = 6
local stock_offset = 7
local stage_offset = 1

--char diff of 116?

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
local stages = {
	[0] = "Peach Castle",
	[1] = "Sector Z",
	[2] = "Kong Jungle",
	[3] = "Planet Zebes",
	[4] = "Hyrule Castle",
	[5] = "Yoshi's Island",
	[6] = "Dream Land",
	[7] = "Saffron City"
}

-- VERY not complete; note different stages of the same animation have different numbers, ex. starting to jump vs. finishing a jump
-- Some animations are unique to certain characters
local animations = {
	[10] = "Idle",
	[20] = "Jump",
	[27] = "Jump",
	[31] = "Landing",
	[212] = "Up Air Attack"
}

-- This value does not differentiate between team and non-team versions of these modes
local game_types = {
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
-- note between matches all players get garbage values, and during matches absent players get garbage
local players = {
	{p = 1, type = 0, dmg = 0, deaths = 0, x = 0, y = 0, char = nil},
	{p = 2, type = 0, dmg = 0, deaths = 0, x = 0, y = 0, char = nil},
	{p = 3, char = nil, x = 0, y = 0, type = 0},
	{p = 4, char = nil, x = 0, y = 0, type = 0}
}

---------------------------------------------------------------------------------
-- Functions to retrieve info

local function in_memory(loc)
	-- values can go out of range while a battle is not occurring
	return loc <= readable_max and loc >=0
end

local function update_time()
	local mins = (mainmemory.readbyte(timer_1) * 10) + mainmemory.readbyte(timer_2)
	local secs = (mainmemory.readbyte(timer_3) * 10) + mainmemory.readbyte(timer_4)
	game.timer = mins * 60 + secs
end

--These should not change during the match
local function update_game_info()
	--players[4].time = mainmemory.read_u32_be(game_loc) --2148158728 timed 2148158728 stock -> 675080
	game.match_type = mainmemory.readbyte(game_loc + match_offset)
	game.time_limit = mainmemory.readbyte(game_loc + time_offset) * 60
	game.stock_limit = mainmemory.readbyte(game_loc + stock_offset) + 1 -- this value always reads as the actual stock number - 1 for some reason
	game.stage = mainmemory.readbyte(game_loc + stage_offset)
	-- Player type is stored here and not in the player objects
	local game_players = game_loc + type_offset
	for i = 0, 3 do
		players[i+1].type = mainmemory.readbyte(game_players + 116 * i)
	end

	update_time()
end

local function update_coords(player_start, playerno)
	-- rounding to 4 places
	--local unrounded_x = mainmemory.readfloat(player_start + x_offset, true);
	local test = mainmemory.read_u32_be(player_start + x_offset);
	players[playerno].x = test
	test = test - 2147483648
	if in_memory(test) then
		players[playerno].y = mainmemory.readfloat(test, true)
	end
	-- if type(unrounded_x) == "number" then
	-- 	players[playerno].x = math.floor(unrounded_x * 10000 + 0.5) / 10000
	-- end
	-- local unrounded_y = mainmemory.readfloat(player_start + x_offset + y_offset, true);
	-- if type(unrounded_y) == "number" then
	-- 	players[playerno].y = math.floor(unrounded_y * 10000 + 0.5) / 10000
	-- end
end

local function update_players()
	-- players[1].be = mainmemory.read_u32_be(player_loc) --2150029272 timed 2150029272 stock -> 2545624
	for i = 0, 3 do
		if players[i+1].type ~= 2 then --dont bother with absent characters
			local playern = player_loc + i * player_offset;
			players[i+1].char = mainmemory.readbyte(playern + char_offset)
			--update_coords(playern, i+1)
		end
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

local function draw_vals()
	local i = 1
	for index, player_vals in ipairs(players) do
		-- print player name first (unordered table)
		gui.drawText(txt_buf, txt_buf * i, "P"..player_vals.p, txt_color, 5)
		i = i + 1
		-- print rest
		for k, v in pairs(player_vals) do
			if k ~= 'p' then
				gui.drawText(txt_buf, txt_buf * i, k..": "..v, txt_color, 5)
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
	update_dmg()
	update_deaths()


	draw_vals()

	emu.frameadvance();
end
