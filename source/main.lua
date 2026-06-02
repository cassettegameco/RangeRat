import "CoreLibs/graphics"
import "CoreLibs/sprites"

local pd = playdate
local gfx = pd.graphics

local showCrankHUD = false


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

    if showCrankHUD == true then
        local crankPosition = pd.getCrankPosition() -- club/swing direction or aim angle
        local crankChange, acceleratedChange = pd.getCrankChange() -- swing motion, tempo/power/fatigue risk
        local crankDocked = pd.isCrankDocked() -- show "pull out crank prompt"

        gfx.drawText("Position: " .. math.floor(crankPosition) .. "deg", 20, 20)
        gfx.drawText("Change: " .. math.floor(crankChange), 20, 40)
        gfx.drawText("Accel: " .. math.floor(acceleratedChange), 20, 60)
        gfx.drawText("Docked: " .. tostring(crankDocked), 20, 80)

        local cx, cy = 320, 120
        local radius = 40

        gfx.drawCircleAtPoint(cx, cy, radius)

        local angle = math.rad(crankPosition - 90)
        local x = cx + math.cos(angle) * radius
        local y = cy + math.sin(angle) * radius

        gfx.drawLine(cx, cy, x, y)
    end

    golfer:draw(golferX, golferY)

    if pd.buttonJustPressed(pd.kButtonB) then
        print("Button B Pressed")
        if showCrankHUD == false then
            showCrankHUD = true
        else
            showCrankHUD = false
        end
    end
end