import "CoreLibs/graphics"
import "CoreLibs/sprites"

local pd = playdate
local gfx = pd.graphics

-- ---------- BACKGROUND ----------
local rangeBgImage = gfx.image.new("images/background_range")
gfx.sprite.setBackgroundDrawingCallback(
    function( x, y, width, height )
        -- x,y,width,height is the updated area in sprite-local coordinates
        -- The clip rect is already set to this area, so we don't need to set it ourselves
        rangeBgImage:draw( 0, 0 )
    end
)

-- ---------- GOLFER ----------
local golferX = 60
local golferY = 165
local golfer = gfx.image.new("images/golfer01")


-- ---------- GAME LOOP ----------
function pd.update()
    gfx.sprite.update()

    golfer:draw(golferX, golferY)
end