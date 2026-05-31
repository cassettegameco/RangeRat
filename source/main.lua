import "CoreLibs/graphics"

local pd = playdate
local gfx = pd.graphics

function pd.update() 
    gfx.drawTextAligned("Range Rat", 200, 40, kTextAlignment.center)
end