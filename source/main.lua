import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

import "sceneManager"
import "scenes/titleScene"

local pd <const> = playdate
local gfx <const> = playdate.graphics

SCENE_MANAGER = SceneManager()

TitleScene()

function pd.update()
    pd.timer.updateTimers()
    gfx.sprite.update()
end
