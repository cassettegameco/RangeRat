local pd = playdate
local gfx = playdate.graphics

class('SceneManager').extends()

function SceneManager:init()
    self.transitionTime = 1000
    self.isTransitioningScene = false
end

-- ... repreents a variable number of arguments
function SceneManager:switchScene(scene, ...)
    if self.isTransitioningScene then
        return
    end

    self.isTransitioningScene = true

    self.newScene = scene
    self.sceneArgs = ...

    self:startTransition()
end

function SceneManager:loadNewScene()
    self:cleanupScene()
    self.newScene(self.sceneArgs)
end

function SceneManager:startTransition()
    local transitionTimer = self:wipeTransition(0, 400)

    transitionTimer.timerEndedCallback = function()
        self:loadNewScene()
        transitionTimer = self:wipeTransition(400, 0)
        transitionTimer.timerEndedCallback = function()
            self.isTransitioningScene = false
        end
    end
end

function SceneManager:wipeTransition(startValue, endValue)
    local transitionSprite = self:createTransitionSprite()
    transitionSprite:setClipRect(0, 0, startValue, 240)

    local transitionTimer = pd.timer.new(self.transitionTime, startValue, endValue, pd.easingFunctions.inOutCubic)

    transitionTimer.updateCallback = function(timer)
        transitionSprite:setClipRect(0, 0, timer.value, 240)
    end

    return transitionTimer
end

function SceneManager:createTransitionSprite()
    local filledRect = gfx.image.new(400, 240, gfx.kColorBlack)
    local transitionSprite = gfx.sprite.new(filledRect)

    transitionSprite:moveTo(200, 120)
    transitionSprite:setZIndex(10000)
    transitionSprite:setIgnoresDrawOffset(true)
    transitionSprite:add()

    return transitionSprite
end

function SceneManager:cleanupScene()
    -- removes all currently active sprites
    gfx.sprite.removeAll()
    -- stops all timers
    self:removeAllTimers()
    -- do anything else that needs to be cleaned up
    gfx.setDrawOffset(0, 0)
end

function SceneManager:removeAllTimers()
    local allTimers = pd.timer.allTimers()

    for _, timer in ipairs(allTimers) do
        timer:remove()
    end
end