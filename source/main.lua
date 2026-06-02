import "CoreLibs/graphics"
import "CoreLibs/sprites"

local pd = playdate
local gfx = pd.graphics

local showCrankHUD = false
local smoothedSpeed = 0
local tempoQuality = "BAD" -- ⚠️ make this a table


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

-- ---------- SHOT ----------
local swingState = "READY"
local backswingPower = 0
local downswingPower = 0
local isBackswing = false
local isDownswing = false


-- ---------- GAME LOOP ----------
function pd.update()
    gfx.sprite.update()

    local crankPosition = pd.getCrankPosition() -- club/swing direction or aim angle
    local crankChange, acceleratedChange = pd.getCrankChange() -- swing motion, tempo/power/fatigue risk
    local crankDocked = pd.isCrankDocked() -- show "pull out crank prompt"
    smoothedSpeed = smoothedSpeed * 0.85 + math.abs(crankChange) * 0.15 -- crank velocity smoothing

    isBackswing = crankChange < -1
    isDownswing = crankChange > 1

    if smoothedSpeed <= 4 then
        tempoQuality = "BAD"
    elseif smoothedSpeed > 4 and smoothedSpeed < 8 then
        tempoQuality = "GOOD"
    elseif smoothedSpeed >= 8 then
        tempoQuality = "FAST"
    end

    if showCrankHUD == true then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(10, 10, 120, 160)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawText("Position: " .. math.floor(crankPosition) .. "deg", 20, 20)
        gfx.drawText("Change: " .. math.floor(crankChange), 20, 40)
        gfx.drawText("Accel: " .. math.floor(acceleratedChange), 20, 60)
        gfx.drawText("Docked: " .. tostring(crankDocked), 20, 80)
        gfx.drawText("Speed: " .. math.floor(smoothedSpeed), 20, 100)
        gfx.drawText("Tempo: " .. tempoQuality, 20, 120)
        if isBackswing then
            gfx.drawText("State: BACKSWING " .. backswingPower, 20, 140)
        else
            gfx.drawText("State: DOWNSWING " .. downswingPower, 20, 140)
        end

        local cx, cy = 320, 120
        local radius = 40

        gfx.drawCircleAtPoint(cx, cy, radius)

        local angle = math.rad(crankPosition - 90)
        local x = cx + math.cos(angle) * radius
        local y = cy + math.sin(angle) * radius

        gfx.drawLine(cx, cy, x, y)

        local meterX, meterY = 0, 230
        local meterW, meterH = 400, 10

        gfx.drawRect(meterX, meterY, meterW, meterH)
        local fillW = math.min(smoothedSpeed * 10, meterW)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(meterX, meterY, fillW, meterH)
        gfx.setColor(gfx.kColorBlack)

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