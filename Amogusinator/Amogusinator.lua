local AMOGUS_EMPTY_PIXELS <const> = { Point(0, 0), Point(0, 3), Point(0, 4), Point(2, 4) }
local AMOGUS_GLASS_PIXELS <const> = { Point(2, 1), Point(3, 1) }

local AMOGUS_WIDTH <const> = 4
local AMOGUS_HEIGHT <const> = 5

local MAX_HUE_OFFSET <const> = 20
local MAX_SATURATION_OFFSET <const> = 25
local MAX_VALUE_OFFSET <const> = 25

local MAX_QUAD_TREE_DEPTH <const> = 10

local sprite = app.activeSprite

if sprite == nil then 
    return app.alert("No active sprite")
end

local function quad_tree(rectangle, depth)
    local tree = {
        rectangle = rectangle,
        depth = depth or 0,
        objects = {},
        children = {},
    }

    if tree.depth < MAX_QUAD_TREE_DEPTH then 
        local rectangle = tree.rectangle
        local half_width = rectangle.width
        local half_height = rectangle.height
        local width1 = math.floor(half_width)
        local width2 = math.ceil(half_width)
        local height1 = math.floor(half_height)
        local height2 = math.ceil(half_height)
        local x = rectangle.x
        local y = rectangle.y
        tree.children_rectangles = {
            Rectangle(x, y, width1, height1),
            Rectangle(x, y + height1, width1, height2),
            Rectangle(x + width1, y, width2, height1),
            Rectangle(x + width1, y + height1, width2, height2)
        }
    end

    function tree:insert(object)
        local children_rectangles = self.children_rectangles
        if children_rectangles ~= nil then 
            for i, rectangle in ipairs(children_rectangles) do
                if rectangle:contains(object) then 
                    local children = self.children
                    if children[i] == nil then
                        children[i] = quad_tree(rectangle, self.depth + 1)
                    end
                    children[i]:insert(object)
                    return
                end
            end
        end
        table.insert(self.objects, object)
    end

    function tree:object_intersects(other)
        for _, object in ipairs(self.objects) do
            if object:intersects(other) then 
                return true
            end
        end
        for _, child in ipairs(self.children) do
            if child.rectangle:intersects(other) then
                if child:object_intersects(other) then
                    return true
                end
            end
        end
        return false
    end

    return tree
end

local function table_containt(table, value)
    for _, item in ipairs(table) do
        if item == value then
            return true
        end
    end
    return false
end

local function color_from_number(number)
    local pixelColor = app.pixelColor
    return Color({
        red = pixelColor.rgbaR(number),
        green = pixelColor.rgbaG(number),
        blue = pixelColor.rgbaB(number),
        alpha = pixelColor.rgbaA(number)
    })
end

local function get_pixel(image, x, y)
    return color_from_number(image:getPixel(x, y))
end

local function is_transparent(color)
    return color.alpha < 128
end

local function distance(a, b)
    return math.abs(a - b)
end

local function can_draw_amogus(image, x, y) 
    local first_color = get_pixel(image, x, y)
    if is_transparent(first_color) then
        return false
    end
    for x_offset = 1, AMOGUS_WIDTH - 1 do
        for y_offset = 1, AMOGUS_HEIGHT - 1 do
            local color = get_pixel(image, x + x_offset, y + y_offset)
            if is_transparent(color) or
            distance(first_color.hsvHue, color.hsvHue) > MAX_HUE_OFFSET or
            distance(first_color.hsvSaturation, color.hsvSaturation) > MAX_SATURATION_OFFSET or
            distance(first_color.hsvValue, color.hsvValue) > MAX_VALUE_OFFSET then
                return false
            end
        end
    end
    return true
end

local function get_average_color(image, x, y, width, height)
    local red = 0
    local green = 0
    local blue = 0
    for x_offset = 0, width - 1 do
        for y_offset = 0, height - 1 do
            local color = get_pixel(image, x + x_offset, y + y_offset)
            red = red + color.red
            green = green + color.green
            blue = blue + color.blue
        end
    end
    local pixel_count = width * height
    return Color({
        red = math.floor(red / pixel_count),
        green = math.floor(green / pixel_count),
        blue = math.floor(blue / pixel_count)
    })
end

local function put_image_on_sprite(sprite, image, x, y)
    sprite:newCel(sprite:newLayer(), sprite.frames[1], image, Point(x, y))
    app.command.MergeDownLayer()
end

local function draw_amogus(image, x, y, color)
    color.hsvValue = math.max(color.hsvValue - 0.05, 0)
    local glass_color = Color({
        red = color.red,
        green = color.green,
        blue = color.blue
    })
    if glass_color.hsvValue > 0.5 then 
        glass_color.hsvValue = glass_color.hsvValue - 0.15
    else
        glass_color.hsvValue = glass_color.hsvValue + 0.15
    end
    for x_offset = 0, AMOGUS_WIDTH - 1 do
        for y_offset = 0, AMOGUS_HEIGHT - 1 do
            local pixel_x = x + x_offset
            local pixel_y = y + y_offset
            if pixel_x >= image.width or pixel_y >= image.height then
                return
            end
            local point = Point(x_offset, y_offset)
            if not table_containt(AMOGUS_EMPTY_PIXELS, point) then
                local pixel_color = color 
                if table_containt(AMOGUS_GLASS_PIXELS, point) then
                    pixel_color = glass_color
                end
                image:putPixel(pixel_x, pixel_y, app.pixelColor.rgba(pixel_color.red, pixel_color.green, pixel_color.blue))
            end
        end
    end
end

local function fill_sprite_with_amoguses(sprite)
    local image = Image(sprite)
    local tree = quad_tree(sprite.bounds)
    for x = 0, image.width - 1 do
        for y = 0, image.height - 1 do
            if can_draw_amogus(image, x, y) then 
                local rectangle_x = x 
                local rectangle_y = y 
                local rectangle_width = AMOGUS_WIDTH
                local rectangle_height = AMOGUS_HEIGHT 
                if x > 0 then
                    rectangle_x = rectangle_x - 1
                    rectangle_width = rectangle_width + 1
                end
                if y > 0 then 
                    rectangle_y = rectangle_y - 1
                    rectangle_height = rectangle_height + 1
                end
                local rectangle = Rectangle({
                    x = rectangle_x,
                    y = rectangle_y,
                    width = math.min(rectangle_width, image.width - x),
                    height = math.min(rectangle_height, image.height - y),
                })
                if not tree:object_intersects(rectangle) then 
                    draw_amogus(image, x, y, get_average_color(image, x, y, AMOGUS_WIDTH, AMOGUS_HEIGHT))
                    tree:insert(rectangle)
                end
            end
        end
    end

    put_image_on_sprite(sprite, image, 0, 0)
end

fill_sprite_with_amoguses(sprite)