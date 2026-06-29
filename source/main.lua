import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "bezier"

local pd = playdate
local gfx = pd.graphics

local showDebugHUD = false
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
local teePoint = { x = 200, y = 220 }
local landingPoint = { x = 380, y = 20 }
local controlPoint = { x = 200, y = 120 }

-- ---------- SHOT ----------
local isShotActive = false
local shotProgress = 0.0 -- represents how far along animation (normalzied progress from 0.0 to 1.0)
local shotDuration = 0.75

local swingState = "READY"
local backswingPower = 0
local downswingPower = 0
local isBackswing = false
local isDownswing = false


-- ---------- GAME LOOP ----------
function pd.update()
    gfx.clear()

    local time = pd.getCurrentTimeMilliseconds() / 1000
    local animationT = math.sin(time) * 0.5 + 0.5

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
    if showDebugHUD then
        gfx.drawCircleAtPoint(teePoint.x, teePoint.y, 10)
        gfx.drawText("TP", teePoint.x - 30, teePoint.y - 20)

        gfx.drawCircleAtPoint(landingPoint.x, landingPoint.y, 10)
        gfx.drawText("LP", landingPoint.x - 30, landingPoint.y - 20)

        gfx.drawCircleAtPoint(controlPoint.x, controlPoint.y, 10)
        gfx.drawText("CP", controlPoint.x - 30, controlPoint.y - 20)

        --[[
            function Bezier.debugPoints(teePoint, controlPoint, landingPoint, elapsedTime)
                local teeToControl = mix(teePoint, controlPoint, elapsedTime)
                local controlToLanding = mix(controlPoint, landingPoint, elapsedTime)
                local curvePoint = mix(teeToControl, controlToLanding, elapsedTime)

                return teeToControl, controlToLanding, curvePoint
            end
        ]]

        local teeToControl, controlToLanding, curvePoint = Bezier.debugPoints(teePoint, controlPoint, landingPoint, animationT)
        gfx.drawCircleAtPoint(teeToControl.x, teeToControl.y, 7)
        gfx.drawCircleAtPoint(controlToLanding.x, controlToLanding.y, 7)
        gfx.drawCircleAtPoint(curvePoint.x, curvePoint.y, 7)

        gfx.drawLine(teePoint.x, teePoint.y, controlPoint.x, controlPoint.y)
        gfx.drawLine(controlPoint.x, controlPoint.y, landingPoint.x, landingPoint.y)
        gfx.drawLine(teeToControl.x, teeToControl.y, controlToLanding.x, controlToLanding.y)
    end

    -- animate ball along curve
    local ball = Bezier.at(teePoint, controlPoint, landingPoint, animationT)
    gfx.fillCircleAtPoint(ball.x, ball.y, 3)

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

    -- ⚠️ replace HUD with a debug scene
    if showDebugHUD == true then
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
        if showDebugHUD == false then
            showDebugHUD = true
        else
            showDebugHUD = false
        end
    end
end