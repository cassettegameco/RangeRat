import "CoreLibs/graphics"
import "CoreLibs/sprites"

local pd = playdate
local gfx = pd.graphics

local showCrankHUD = false
local smoothedSpeed = 0
local tempoQuality = "BAD" -- ⚠️ make this a table


-- ---------- BACKGROUND ----------
local rangeBgImage = gfx.image.new("images/rangev3")
--[[
gfx.sprite.setBackgroundDrawingCallback(
    function( x, y, width, height )
        -- x,y,width,height is the updated area in sprite-local coordinates
        -- The clip rect is already set to this area, so we don't need to set it ourselves
        rangeBgImage:draw( 0, 0 )
    end
)
]]

-- ---------- BEZIER CURVE EXPERIMENTATION ----------
local pointA = { x = 200, y = 220 }
local pointB = { x = 380, y = 20 }
local pointC = { x = 200, y = 120 }

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function mix(a, b, t)
    return {
        x = lerp(a.x, b.x, t),
        y = lerp(a.y, b.y, t)
    }
end

local function bezier(a, b, c, t)
    return mix(mix(a, c, t), mix(c, b, t), t)
end

-- ---------- SHOT ----------
local swingState = "READY"
local backswingPower = 0
local downswingPower = 0
local isBackswing = false
local isDownswing = false


-- ---------- GAME LOOP ----------
function pd.update()
    gfx.clear()

    local time = pd.getCurrentTimeMilliseconds() / 1000
    local t = math.sin(time) * 0.5 + 0.5

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

    -- ---------- Bezier Curve Experimation - START ----------
    gfx.drawCircleAtPoint(pointA.x, pointA.y, 10)
    gfx.drawCircleAtPoint(pointB.x, pointB.y, 10)
    gfx.drawCircleAtPoint(pointC.x, pointC.y, 10)

    local pointAC = mix(pointA, pointC, t)
    local pointCB = mix(pointC, pointB, t)
    gfx.drawCircleAtPoint(pointAC.x, pointAC.y, 7)
    gfx.drawCircleAtPoint(pointCB.x, pointCB.y, 7)

    local pointACB = mix(pointAC, pointCB, t)
    gfx.drawCircleAtPoint(pointACB.x, pointACB.y, 7)

    gfx.drawLine(pointA.x, pointA.y, pointC.x, pointC.y)
    gfx.drawLine(pointC.x, pointC.y, pointB.x, pointB.y)
    gfx.drawLine(pointAC.x, pointAC.y, pointCB.x, pointCB.y)

    -- Approximate curve with filled circles drawing a dotted curve
    local previousPoint = pointA
    local newPoint = pointA
    for i = 1, 25, 1 do
        t = i/25

        newPoint = bezier(pointA, pointB, pointC, t)

        gfx.fillCircleAtPoint(newPoint.x, newPoint.y, 5)

        previousPoint = newPoint
    end

    if pd.buttonIsPressed(pd.kButtonUp) then
        pointC.y -= 1
    elseif pd.buttonIsPressed(pd.kButtonRight) then
        pointC.x += 1
    elseif pd.buttonIsPressed(pd.kButtonDown) then
        pointC.y += 1
    elseif pd.buttonIsPressed(pd.kButtonLeft) then
        pointC.x -= 1
    end
    -- ---------- Bezier Curve Experimation - END ----------

    -- ⚠️ replace HUD with a debug scene
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

        local meterX, meterY = 0, 230
        local meterW, meterH = 400, 10

        gfx.drawRect(meterX, meterY, meterW, meterH)
        local fillW = math.min(smoothedSpeed * 10, meterW)
        gfx.fillRect(meterX, meterY, fillW, meterH)

    end

    if pd.buttonJustPressed(pd.kButtonB) then
        print("Button B Pressed")
        if showCrankHUD == false then
            showCrankHUD = true
        else
            showCrankHUD = false
        end
    end
end