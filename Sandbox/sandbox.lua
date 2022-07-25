local current_sprite = app.activeSprite
local ignore_changes = false

local function apply_gravity(sprite)
    ignore_changes = true
    local image = Image(sprite)
    local width = image.width
    local height = image.height
    for x = width - 1, 0, -1 do
        for y = height - 1, 0, -1 do
            local color = image:getPixel(x, y)
            if app.pixelColor.rgbaA(color) > 0 then
                local ny = height - 1
                for i = y + 1, ny do
                    if app.pixelColor.rgbaA(image:getPixel(x, i)) > 0 then
                        ny = i - 1
                        break
                    end
                end
                image:putPixel(x, y, Color{
                    red = 0,
                    green = 0,
                    blue = 0,
                    alpha = 0
                })
                image:putPixel(x, ny, color)
            end
        end
    end
    sprite:deleteLayer(sprite.layers[1])
    sprite:newCel(sprite:newLayer(), sprite.frames[1], image, Point(0, 0))
    app.refresh()
    ignore_changes = false
end

local function on_change()
    if ignore_changes then
        return
    end
    apply_gravity(current_sprite)
end

if current_sprite == nil then
    return app.alert("No active sprite")
end

current_sprite.events:on("change", on_change)
on_change()
