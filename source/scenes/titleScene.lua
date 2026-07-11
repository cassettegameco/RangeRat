import "scenes/gameScene"

local pd <const> = playdate
local gfx <const> = playdate.graphics

class ('TitleScene').extends(gfx.sprite)

function TitleScene:init()
    -- Draw title image
    -- 1. load titleImage
    local titleImage <const> = gfx.image.new("images/titleImage")
    -- 2. confirm titleImage has loaded
    assert(titleImage, "titleImage failed to load")
    -- 3. draw titleImage on screen
    gfx.sprite.setBackgroundDrawingCallback(function()
        titleImage:draw(0, 0)
    end)

    -- required or update method for scene will not be called
    self:add()
end

function TitleScene:update()
    if pd.buttonJustPressed(pd.kButtonA) then
        SCENE_MANAGER:switchScene(GameScene)
    end
end
