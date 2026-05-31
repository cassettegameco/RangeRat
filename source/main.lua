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

function pd.update()
    gfx.sprite.update()
end