-- This template lives at `.../Lua/.template.lua`.

-- DWORD unsigned Big Endian
local p1_dmg_loc = 0x0A4D74
local p2_dmg_loc = 0x0A4DE8
local p1_death_loc = 0x0A4D38
local p2_death_loc = 0x0A4D3C

-- floats
local p2_x_loc = 0x2F8BA4
local p1_x_loc = 0x2F48B4

local txt_color = 0xFF000000
local txt_buf = 10

local players = {
	{p = 1, dmg = 0, deaths = 0, x = 0, y = 0},
	{p = 2, dmg = 0, deaths = 0, x = 0, y = 0}
}

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
		gui.drawText(txt_buf, txt_buf * i, "P"..player_vals.p, txt_color, 9)
		i = i + 1
		-- print rest
		for k, v in pairs(player_vals) do
			if k ~= 'p' then
				gui.drawText(txt_buf, txt_buf * i, k..": "..v, txt_color, 9)
				i = i + 1
			end
		end
	end
end

while true do
	update_dmg()
	update_deaths()
	update_x()

	draw_vals()

	emu.frameadvance();
end
