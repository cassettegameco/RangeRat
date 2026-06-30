import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "bezier"

local pd = playdate
local gfx = pd.graphics
local showDebugHUD = false

local SwingState = {
    Ready = "READY",
    Backswing = "BACKSWING",
    Downswing = "DOWNSWING",
    Flight = "FLIGHT"
}

--[[
ShotQuality = backswing amount + downswing speed + tempo ratio
    - backswing power:      how much the player loaded the swing
    - downswing speed:      how fast the player came through impact
    - tempo quality:        whether the downswing was proportional to the backswing
    - shot quality:         the final result of combining tempo, power, and later tilt
]]
local ShotQuality = {
    Pure = "PURE",
    Weak = "WEAK",
    Rushed = "RUSHED",
    Mishit = "MISHIT"
}

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
local teePoint = { x = 300, y = 220 }
local landingPoint = { x = 280, y = 20 }
local controlPoint = { x = 300, y = 120 }

-- ---------- SHOT ----------
local shotStartTime = 0.0
local shotProgress = 0.0 -- represents how far along animation (normalzied progress from 0.0 to 1.0)
local shotDuration = 0.75

local swingState = SwingState.Ready
local backswingPower = 0.0
local downswingPower = 0.0
local tempoRatio = 0.0
local currentShotQuality = ShotQuality.Weak
local swingThreshold = 8

local gravityX = 0
local gravityY = 0
local gravityZ = 0

-- ⚠️ consider splitting into separate functions, calculateTempoQuality and calculateShotQuality
local function evaluateShotQuality(backswingPower, downswingPower)
    -- avoid division by zero
    if backswingPower <= 0 then
        return ShotQuality.Mishit, 0
    end

    -- tempo ratio compares how aggressive the downswing was relative to the backswing
    -- ~1.0 means the downswing matches the backswing
    local ratio = downswingPower / backswingPower

    if backswingPower < 10 then
        return ShotQuality.Weak, ratio
    elseif ratio >= 0.8 and ratio <= 1.4 then
        return ShotQuality.Pure, ratio
    elseif ratio > 1.4 and ratio <= 2.0 then
        return ShotQuality.Rushed, ratio
    else
        return ShotQuality.Mishit, ratio
    end
end

-- ⚠️ is off by default to save power, stop to put back in lower-power state
pd.startAccelerometer()

-- ---------- GAME LOOP ----------
function pd.update()
    gfx.clear()

    gravityX, gravityY, gravityZ = pd.readAccelerometer()

    local time = pd.getCurrentTimeMilliseconds() / 1000
    local animationT = math.sin(time) * 0.5 + 0.5

    gfx.sprite.update()

    local crankPosition = pd.getCrankPosition() -- club/swing direction or aim angle
    local crankChange, acceleratedChange = pd.getCrankChange() -- swing motion, tempo/power/fatigue risk

    -- ---------- Bezier Curve Experimation ----------
    if showDebugHUD then
        gfx.drawCircleAtPoint(teePoint.x, teePoint.y, 10)
        gfx.drawText("TP", teePoint.x - 30, teePoint.y - 20)

        gfx.drawCircleAtPoint(landingPoint.x, landingPoint.y, 10)
        gfx.drawText("LP", landingPoint.x - 30, landingPoint.y - 20)

        gfx.drawCircleAtPoint(controlPoint.x, controlPoint.y, 10)
        gfx.drawText("CP", controlPoint.x - 30, controlPoint.y - 20)

        local teeToControl, controlToLanding, curvePoint = Bezier.debugPoints(teePoint, controlPoint, landingPoint, animationT)
        gfx.drawCircleAtPoint(teeToControl.x, teeToControl.y, 7)
        gfx.drawCircleAtPoint(controlToLanding.x, controlToLanding.y, 7)
        gfx.drawCircleAtPoint(curvePoint.x, curvePoint.y, 7)

        gfx.drawLine(teePoint.x, teePoint.y, controlPoint.x, controlPoint.y)
        gfx.drawLine(controlPoint.x, controlPoint.y, landingPoint.x, landingPoint.y)
        gfx.drawLine(teeToControl.x, teeToControl.y, controlToLanding.x, controlToLanding.y)

        gfx.drawText("State: " .. swingState, 20, 20)
        gfx.drawText("Shot: " .. currentShotQuality, 20, 40)
        gfx.drawText("Back: " .. math.floor(backswingPower), 20, 60)
        gfx.drawText("Down: " .. math.floor(downswingPower), 20, 80)
        gfx.drawText("Ratio: " .. string.format("%.2f", tempoRatio), 20, 100) 
        gfx.drawText("Tilt: " .. tostring(gravityX) .. ", " .. tostring(gravityY) .. ", " .. tostring(gravityZ), 20, 120) 
    end

    -- ---------- SWING STATE MACHINE ----------
    if swingState == SwingState.Ready then -- READY
        -- reset swing measurements before starting a new swing
        backswingPower = 0
        downswingPower = 0
        tempoRatio = 0
    
        -- a backswing is negative crank movement above a threshold
        if crankChange < -swingThreshold then
            backswingPower = math.abs(crankChange)
            swingState = SwingState.Backswing
        end
    elseif swingState == SwingState.Backswing then -- BACKSWING
        -- while in backswing, keep the strongest backwards crank movement
        -- this represents how much the player loaded the swing
        if crankChange < 0 then
            backswingPower = math.max(backswingPower, math.abs(crankChange))
        end
    
        -- a downswing is positive crank movement after a valid backswing
        -- trigger test shot
        if crankChange > swingThreshold then
            downswingPower = crankChange

            -- evaluate shot quality at impact
            currentShotQuality, tempoRatio = evaluateShotQuality(backswingPower, downswingPower)

            shotStartTime = pd.getCurrentTimeMilliseconds() / 1000
            shotProgress = 0.0
            swingState = SwingState.Flight
        end
    elseif swingState == SwingState.Flight then -- FLIGHT
        local currentTime = pd.getCurrentTimeMilliseconds() / 1000
        local elapsed = currentTime - shotStartTime

        shotProgress = math.min(elapsed / shotDuration, 1.0)

        local ball = Bezier.at(teePoint, controlPoint, landingPoint, shotProgress)
        gfx.fillCircleAtPoint(ball.x, ball.y, 5)

        if shotProgress >= 1.0 then
            swingState = SwingState.Ready
        end
    end
    -- ------------------------------------------

    --[[ Approximate curve with filled circles drawing a dotted curve
    for i = 1, 25, 1 do
        local curveT = i/25
        local point = bezier(teePoint, landingPoint, controlPoint, curveT)
        gfx.fillCircleAtPoint(point.x, point.y, 5)
    end
    ]]

    if pd.buttonIsPressed(pd.kButtonUp) then
        controlPoint.y -= 1
    elseif pd.buttonIsPressed(pd.kButtonRight) then
        controlPoint.x += 1
    elseif pd.buttonIsPressed(pd.kButtonDown) then
        controlPoint.y += 1
    elseif pd.buttonIsPressed(pd.kButtonLeft) then
        controlPoint.x -= 1
    end
    -- ---------- Bezier Curve Experimation - END ----------

    if pd.buttonJustPressed(pd.kButtonB) then
        print("Button B Pressed")
        if showDebugHUD == false then
            showDebugHUD = true
        else
            showDebugHUD = false
        end
    end
end