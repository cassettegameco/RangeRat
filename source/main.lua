import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/animation"
import "bezier"

local pd = playdate
local gfx = pd.graphics

local golferTable = gfx.imagetable.new("images/Rat-v1")
assert(golferTable, "Could not load golfer imagetable")

local golferAnimation = gfx.animation.loop.new(100, golferTable, false)
local golfer = gfx.sprite.new()
golfer:setImage(golferTable:getImage(1))
golfer:moveTo(180, 200)

local isGolferAnimating = false
local pendingBallFlight = false
local swingAnimationStartTime = 0
local swingAnimationDuration = 200


function golfer:update()
    if isGolferAnimating then
        self:setImage(golferAnimation:image())
    else
        self:setImage(golferTable:getImage(1))
    end
end

golfer:add()

local TestImpactSoundSet = {
    pd.sound.fileplayer.new("sounds/ballHit1"),
    pd.sound.fileplayer.new("sounds/ballHit2"),
    pd.sound.fileplayer.new("sounds/ballHit3"),
    pd.sound.fileplayer.new("sounds/ballHit4")
}

--[[
local ImpactSoundSet = {
    Pure = { -- crack
        hit1,
        hit2,
        hit3
    },
    Weak = { -- thud
        weak1,
        weak2
    },
    Rushed = { -- harder crack
        rushed1,
        rushed2
    },
    Mishit = { -- chunk
        mishit1,
        mishit2,
        mishit3
    }
}
]]

local showDebugHUD = false
local showDebugLines = false
local showSwingMeter = false

local SwingState = {
    Ready = "READY",
    Backswing = "BACKSWING",
    Downswing = "DOWNSWING",
    Flight = "FLIGHT",
    BucketComplete = "BUCKET_COMPLETE" -- ⚠️ This is more a game state than a swing state, move this when implementing scene management
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

local ShotShape = {
    Hook = "HOOK",
    Draw = "DRAW",
    Straight = "STRAIGHT",
    Fade = "FADE",
    Slice = "SLICE"
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

-- ---------- BUCKET ----------
local Bucket = {
    Small = 10,
    Medium = 15,
    Large = 20
}
local selectedBucket = Bucket.Small
local currentShot = 0

-- ---------- SCORING ----------
local ShotScore = {
    PURE = 100,
    RUSHED = 70,
    WEAK = 40,
    MISHIT = 0
}

local currentBucketScore = 0

local ShotTracker = {
    PURE = 0,
    RUSHED = 0,
    WEAK = 0,
    MISHIT = 0
}

-- ---------- BALL ----------
local teePoint = { x = 200, y = 220 }
local landingPoint = { x = 200, y = 20 }
local controlPoint = { x = 200, y = 120 }

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

local currentDeviceTiltX = 0.0
local deviceTiltAtImpact = 0.0
local currentShotShape = ShotShape.Straight
local straightTiltThreshold = 0.05
local severeTiltThreshold = 0.18

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

--[[
- deviceTiltX = left/right device tilt at impact
- -tilt = left curve / +tilt = right curve
- there is a small tilt threshold so the player has a fair dead zone
]]
local function evaluateShotShape(deviceTilt)
    local absTilt = math.abs(deviceTilt)

    if absTilt < straightTiltThreshold then
        return ShotShape.Straight
    end

    if deviceTilt < 0 then
        if absTilt >= severeTiltThreshold then
            return ShotShape.Hook
        else
            return ShotShape.Draw
        end
    else
        if absTilt >= severeTiltThreshold then
           return ShotShape.Slice 
        else
            return ShotShape.Fade
        end
    end
end

local function applyShotShape(shape)
    -- reset to a default centered shot first
    controlPoint.x = 200
    landingPoint.x = 200

    if shape == ShotShape.Hook then
        controlPoint.x = 170
        landingPoint.x = 125
    elseif shape == ShotShape.Draw then
        controlPoint.x = 190
        landingPoint.x = 175
    elseif shape == ShotShape.Straight then
        controlPoint.x = 200
        landingPoint.x = 200
    elseif shape == ShotShape.Fade then
        controlPoint.x = 210
        landingPoint.x = 225
    elseif shape == ShotShape.Slice then
        controlPoint.x = 230
        landingPoint.x = 275
    end
end

local function applyShotQuality(quality)
    if quality == ShotQuality.Pure then
        landingPoint.y = 20   -- far
        controlPoint.y = 80   -- high arc
        shotDuration = 0.75

    elseif quality == ShotQuality.Weak then
        landingPoint.y = 90   -- shorter
        controlPoint.y = 150  -- lower/softer arc
        shotDuration = 0.65

    elseif quality == ShotQuality.Rushed then
        landingPoint.y = 40   -- still travels
        controlPoint.y = 125  -- lower, flatter arc
        shotDuration = 0.55

    elseif quality == ShotQuality.Mishit then
        landingPoint.y = 150  -- very short
        controlPoint.y = 190  -- ugly low dribbler
        shotDuration = 0.45
    end
end

local feedbackText = nil
local feedbackTextStartTime = 0
local feedbackTextDuration = 750 --milliseconds

local function showFeedbackText(text)
    feedbackText = text
    feedbackTextStartTime = pd.getCurrentTimeMilliseconds()
end

local lastShotDebug = {
    backswing = 0,
    downswing = 0,
    ratio = 0,
    quality = "",
    shape = ""
}

local function drawSwingDebug()
    local meterX = 20
    local meterY = 100
    local meterWidth = 120
    local meterHeight = 8


    if swingState == SwingState.BucketComplete then
                gfx.drawText("State: DONE", meterX, meterY - 20)

    else
        gfx.drawText("State: " .. swingState, meterX, meterY - 20)
    end
    gfx.drawText("Quality: " .. lastShotDebug.quality, meterX, meterY)
    gfx.drawText("Back: " .. math.floor(lastShotDebug.backswing), meterX, meterY + 20)
    gfx.drawText("Down: " .. math.floor(lastShotDebug.downswing), meterX, meterY + 40)
    gfx.drawText("Ratio: " .. string.format("%.2f", lastShotDebug.ratio), meterX, meterY + 60)

    -- backswing bar
    gfx.drawRect(meterX, meterY + 85, meterWidth, meterHeight)
    gfx.fillRect(meterX, meterY + 85, math.min(lastShotDebug.backswing * 4, meterWidth), meterHeight)

    -- downswing bar
    gfx.drawRect(meterX, meterY + 105, meterWidth, meterHeight)
    gfx.fillRect(meterX, meterY + 105, math.min(lastShotDebug.downswing * 4, meterWidth), meterHeight)

    gfx.drawText("BACK", meterX + meterWidth + 8, meterY + 80)
    gfx.drawText("DOWN", meterX + meterWidth + 8, meterY + 100)
end

--[[
local function playBallImpactSound(shotQuality)
    local soundSet = ImpactSoundSet[currentShotQuality]
    soundSet[math.random(#soundSet)]:play()
end
]]

-- ⚠️ is off by default to save power, stop to put back in lower-power state
-- ⚠️ is this the best way to do this or should i turn it on/off in state machine 
-- ⚠️ so it would only be on when it is needed?
pd.startAccelerometer()

-- ---------- GAME LOOP ----------
function pd.update()
    gfx.clear()

    -- read device tilt every frame
    -- x is left/right / y is forward/backward / z is vertical orientation
    local tiltX, tiltY, tiltZ = pd.readAccelerometer()
    currentDeviceTiltX = tiltX

    local time = pd.getCurrentTimeMilliseconds() / 1000
    local animationT = math.sin(time) * 0.5 + 0.5

    gfx.sprite.update()

    local crankPosition = pd.getCrankPosition() -- club/swing direction or aim angle
    local crankChange, acceleratedChange = pd.getCrankChange() -- swing motion, tempo/power/fatigue risk

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

            deviceTiltAtImpact = currentDeviceTiltX 

            -- evaluate shot quality and shape at impact
            currentShotQuality, tempoRatio = evaluateShotQuality(backswingPower, downswingPower)
            currentShotShape = evaluateShotShape(deviceTiltAtImpact)

            lastShotDebug.backswing = backswingPower
            lastShotDebug.downswing = downswingPower
            lastShotDebug.ratio = tempoRatio
            lastShotDebug.quality = currentShotQuality
            lastShotDebug.shape = currentShotShape

            -- score shot
            ShotTracker[currentShotQuality] += 1
            showFeedbackText(currentShotQuality)
            currentBucketScore += ShotScore[currentShotQuality]

            -- apply shot shape and quality to build curve
            applyShotShape(currentShotShape)
            applyShotQuality(currentShotQuality)

            golferAnimation.frame = 1
            isGolferAnimating = true
            swingAnimationStartTime = pd.getCurrentTimeMilliseconds()
            swingState = SwingState.Downswing
        end
    elseif swingState == SwingState.Downswing then -- DOWNSWING
        local elapsed = pd.getCurrentTimeMilliseconds() - swingAnimationStartTime

        if elapsed >= swingAnimationDuration then
            isGolferAnimating = false
            golfer:setImage(golferTable:getImage(1))

            shotStartTime = pd.getCurrentTimeMilliseconds() / 1000
            shotProgress = 0.0

            local randomHitSound = TestImpactSoundSet[math.random(1, #TestImpactSoundSet)]
            randomHitSound:play()
            currentShot += 1

            swingState = SwingState.Flight
        end
    elseif swingState == SwingState.Flight then -- FLIGHT
        local currentTime = pd.getCurrentTimeMilliseconds() / 1000
        local elapsed = currentTime - shotStartTime

        shotProgress = math.min(elapsed / shotDuration, 1.0)

        local ball = Bezier.at(teePoint, controlPoint, landingPoint, shotProgress)
        gfx.fillCircleAtPoint(ball.x, ball.y, 5)

        if shotProgress >= 1.0 then
            if currentShot == selectedBucket then
                swingState = SwingState.BucketComplete
            else
                swingState = SwingState.Ready
            end
        end
    elseif swingState == SwingState.BucketComplete then
        if not feedbackText then
            gfx.drawTextAligned("Bucket Complete!", 200, 30, kTextAlignment.center)
        
            gfx.drawTextAligned("Score: " .. currentBucketScore, 200, 70, kTextAlignment.center)
            gfx.drawTextAligned("Pure: " .. ShotTracker.PURE, 200, 90, kTextAlignment.center)
            gfx.drawTextAligned("Rushed: " .. ShotTracker.RUSHED, 200, 110, kTextAlignment.center)
            gfx.drawTextAligned("Weak: " .. ShotTracker.WEAK, 200, 130, kTextAlignment.center)
            gfx.drawTextAligned("Mishit: " .. ShotTracker.MISHIT, 200, 150, kTextAlignment.center)


            gfx.drawTextAligned("Press A to Restart", 200, 190, kTextAlignment.center)

            if pd.buttonJustPressed(pd.kButtonA) then
                currentShot = 0
                currentBucketScore = 0
                ShotTracker.PURE = 0
                ShotTracker.RUSHED = 0
                ShotTracker.MISHIT = 0
                ShotTracker.WEAK = 0
                swingState = SwingState.Ready
            end
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

    -- ---------- DEBUG ----------
    if pd.buttonJustPressed(pd.kButtonB) then
        if not showDebugHUD and not showDebugLines and not showSwingMeter then
            showDebugHUD = false
            showDebugLines = false
            showSwingMeter = true
        elseif not showDebugHUD and not showDebugLines and showSwingMeter then
            showDebugHUD = false
            showDebugLines = true
            showSwingMeter = false
        elseif not showDebugHUD and showDebugLines and not showSwingMeter then
            showDebugHUD = true
            showDebugLines = false
            showSwingMeter = false
        elseif showDebugHUD then
            showDebugHUD = false
            showDebugLines = false
            showSwingMeter = false
        end
    end
    
    gfx.drawText("Score: " .. currentBucketScore, 310, 10)
    gfx.drawText(selectedBucket .. " Bucket", 310, 200)
    gfx.drawText("Shot: " .. currentShot .. "/" .. selectedBucket, 310, 220)

    if showDebugHUD then
        gfx.drawText("State: " .. swingState, 20, 20)
        gfx.drawText("Shot: " .. currentShotQuality, 20, 40)
        gfx.drawText("Back: " .. math.floor(backswingPower), 20, 60)
        gfx.drawText("Down: " .. math.floor(downswingPower), 20, 80)
        gfx.drawText("Ratio: " .. string.format("%.2f", tempoRatio), 20, 100) 
        gfx.drawText(string.format("Tilt: %.2f", deviceTiltAtImpact), 20, 120)
        gfx.drawText("Shape: " .. currentShotShape, 20, 140)
    end

    if showDebugLines then
        gfx.drawCircleAtPoint(teePoint.x, teePoint.y, 10)
        gfx.drawText("TP", teePoint.x - 30, teePoint.y - 20)

        gfx.drawCircleAtPoint(125, 150, 10)
        gfx.drawCircleAtPoint(125, 90, 10)
        gfx.drawCircleAtPoint(125, 40, 10)
        gfx.drawCircleAtPoint(125, 20, 10)

        gfx.drawCircleAtPoint(175, 150, 10)
        gfx.drawCircleAtPoint(175, 90, 10)
        gfx.drawCircleAtPoint(175, 40, 10)
        gfx.drawCircleAtPoint(175, 20, 10)

        gfx.drawCircleAtPoint(200, 150, 10)
        gfx.drawCircleAtPoint(200, 90, 10)
        gfx.drawCircleAtPoint(200, 40, 10)
        gfx.drawCircleAtPoint(200, 20, 10)

        gfx.drawCircleAtPoint(225, 150, 10)
        gfx.drawCircleAtPoint(225, 90, 10)
        gfx.drawCircleAtPoint(225, 40, 10)
        gfx.drawCircleAtPoint(225, 20, 10)

        gfx.drawCircleAtPoint(275, 150, 10)
        gfx.drawCircleAtPoint(275, 90, 10)
        gfx.drawCircleAtPoint(275, 40, 10)
        gfx.drawCircleAtPoint(275, 20, 10)
        --gfx.drawCircleAtPoint(landingPoint.x, landingPoint.y, 10)
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
    end

    if showSwingMeter then
        drawSwingDebug()
    end

    if feedbackText then
        local elapsed = pd.getCurrentTimeMilliseconds() - feedbackTextStartTime

        if elapsed < feedbackTextDuration then
            gfx.drawTextAligned(feedbackText, 200, 120, kTextAlignment.center)
        else
            feedbackText = nil
        end
    end
end