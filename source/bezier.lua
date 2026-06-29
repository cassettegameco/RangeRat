-- Create empty lua table which can be compared to what the purpose of a  struct/class servces in Swift
Bezier = {}

-- local because only code within bezier.lua needs to know how to interpolate numbers
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- ⚠️ add a comment here at some point
local function mix(a, b, t)
    return {
        x = lerp(a.x, b.x, t),
        y = lerp(a.y, b.y, t)
    }
end

function Bezier.debugPoints(teePoint, controlPoint, landingPoint, elapsedTime)
    local teeToControl = mix(teePoint, controlPoint, elapsedTime)
    local controlToLanding = mix(controlPoint, landingPoint, elapsedTime)
    local curvePoint = mix(teeToControl, controlToLanding, elapsedTime)

    return teeToControl, controlToLanding, curvePoint
end

function Bezier.at(teePoint, controlPoint, landingPoint, elapsedTime)
    local teeToControl = mix(teePoint, controlPoint, elapsedTime)
    local controlToLanding = mix(controlPoint, landingPoint, elapsedTime)

    return mix(teeToControl, controlToLanding, elapsedTime)
end

return Bezier