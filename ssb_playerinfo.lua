-- This template lives at `.../Lua/.template.lua`.

-- DWORD unsigned Big Endian
local p1_dmg_loc = 0x0A4D74
local p2_dmg_loc = 0x0A4DE8
local p1_death_loc = 0x0A4D38
local p2_death_loc = 0x0A4D3C
local player_loc = 0x130D84

-- floats
local p2_x_loc = 0x2F8BA4
local p1_x_loc = 0x2F48B4


local player_offset = 0xB50
local char_offset = 0x0B

local bus_max = 0x80000000;
local readable_max = 0x800000;


-- luigi, capt falcon, ness, or jigglypuff is 4?
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


----

local txt_color = 0xFF000000
local txt_buf = 10

-- TODO: either add / remove player rows from table as needed or refrain from printing table rows of absent players
local players = {
	{p = 1, dmg = 0, deaths = 0, x = 0, char = 0},
	{p = 2, dmg = 0, deaths = 0, x = 0, char = 0},
	{p = 3, char = 0},
	{p = 4, char = 0}
}

local function in_memory(loc)
	-- values go out of range while a battle is not occurring
	return loc <= readable_max and loc >=0
end

-- TODO: cleanup 
local function update_players()
	--guaranteed to have at least one player
	local player1 = mainmemory.read_u32_be(player_loc) - bus_max;
	players[1].loc = player1
	if in_memory(player1) then
		players[1].char = mainmemory.readbyte(player1 + char_offset)
	end
	--check if there are more players
	for i = 1, 3 do
		local playern = player1 + i * player_offset;
		players[i+1].loc = playern
		if in_memory(player1) then
			players[i+1].char = mainmemory.readbyte(playern + char_offset)
		end
	end

end

-- TODO: fix this for any battle mode and character. currently only works on versus mode mario v yoshi
local function update_x()
	-- rounding to 4 places
	local unrounded_x1 = mainmemory.readfloat(p1_x_loc, true);
	players[1].x = math.floor(unrounded_x1 * 10000 + 0.5) / 10000
	local unrounded_x2 = mainmemory.readfloat(p2_x_loc, true);
	players[2].x = math.floor(unrounded_x2 * 10000 + 0.5) / 10000
end

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

while true do
	update_players()
	update_dmg()
	update_deaths()
	update_x()


	draw_vals()

	emu.frameadvance();
end
