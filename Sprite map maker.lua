local dialog = Dialog({ title = "Sprite map maker" })

local X_ENTRY_ID <const> = "x"
local Y_ENTRY_ID <const> = "y"
local WIDTH_ENTRY_ID <const> = "width"
local HEIGHT_ENTRY_ID <const> = "height"

local DEFAULT_COORDINATE <const> = "0"

dialog:number({ id = "frames_count", label = "Number of frames", text = "3" })
dialog:number({ id = X_ENTRY_ID, label = X_ENTRY_ID, text = DEFAULT_COORDINATE })
dialog:number({ id = Y_ENTRY_ID, label = Y_ENTRY_ID, text = DEFAULT_COORDINATE })
dialog:number({ id = WIDTH_ENTRY_ID, label = WIDTH_ENTRY_ID })
dialog:number({ id = HEIGHT_ENTRY_ID, label = HEIGHT_ENTRY_ID })
dialog:number({ id = "maxFrames", label = "Max frames in one line" , text = "5"})

local DEFAULT_OUTPUT_SPRITE <const> = "Current"
local DEFAULT_MODE <const> = "Duplicate current frame"

local output_sprite = DEFAULT_OUTPUT_SPRITE
local mode = DEFAULT_MODE

dialog:combobox({
    label = "Output sprite",
    options = {
        DEFAULT_OUTPUT_SPRITE,
        "New"
    },
    onchange = function(self)
        output_sprite = self.option
    end
})

dialog:combobox({
    label = "Mode",
    options = {
        DEFAULT_MODE,
        "From all frames"
    },
    onchange = function(self)
        mode = self.option
    end
})

local function crop_image(image, crop_x, crop_y, width, height)
    local result = Image(width, height)
    for x = 0, width - 1 do
        for y = 0, height - 1 do
            local pixel = image:getPixel(crop_x + x, crop_y + y)
            result:putPixel(x, y, pixel)
        end
    end
    return result 
end

local function put_image_on_sprite(sprite, image, point)
    sprite:newCel(sprite:newLayer(), sprite.frames[1], image, point)
    app.command.MergeDownLayer()
end

local function get_image_point(index, max_images_in_line, image_width, image_height)
    return Point(index % max_images_in_line * image_width, math.floor(index / max_images_in_line) * image_height)
end

local function duplicate_image_on_sprite(sprite, image, frames_count, max_images_in_line, image_width, image_height)
    for i = 0, frames_count - 1 do
        put_image_on_sprite(sprite, image, get_image_point(i, max_images_in_line, image_width, image_height))
    end
end

local function put_frames_on_image(image, sourceSprite, frames_count, max_images_in_line, image_x, image_y, image_width, image_height)
    for i = 0, frames_count - 1 do
        local frame_index = i + 1
        local frames = sourceSprite.frames
        if frame_index > #frames then
            break
        end
        local frame_image = Image(sourceSprite.width, sourceSprite.height)
        frame_image:drawSprite(sourceSprite, frame_index)
        local cropped_image = crop_image(frame_image, image_x, image_y, image_width, image_height)
        image:drawImage(cropped_image, get_image_point(i, max_images_in_line, image_width, image_height))
    end
end

local function show_no_active_sprite_allert()
    app.alert("No active sprite")
    dialog:close()
end

local function clear_sprite(sprite)
    for i, frame in ipairs(sprite.frames) do
        sprite:newCel(sprite.layers[1], frame) 
    end
end

local function create_sprite_set_palette(width, height, palette)
    local sprite = Sprite(width, height)
    sprite:setPalette(palette)
    return sprite
end

local function create_sprite_map()
    local original_sprite = app.activeSprite
    
    if original_sprite == nil then
        show_no_active_sprite_allert()
        return
    end

    local data = dialog.data
    local frames_entered = data.frames_count

    if frames_entered <= 1 then
        return
    end

    local frames_count = frames_entered
    if mode ~= DEFAULT_MODE then
        frames_count = math.min(frames_count, #original_sprite.frames)
    end

    local frame_x = data.x
    local frame_y = data.y
    local frame_width = data.width
    local frame_height = data.height

    if frame_x + frame_width > original_sprite.width or frame_y + frame_height > original_sprite.height then
        app.alert("The bounds are set incorrectly")
        return
    end

    local max_frames_in_line = dialog.data.maxFrames
    local map_width = math.min(frames_count, max_frames_in_line) * frame_width
    local map_height = math.ceil(frames_count / max_frames_in_line) * frame_height

    local palette = original_sprite.palettes[1]

    if mode == DEFAULT_MODE then
        local frame_image = crop_image(Image(original_sprite), frame_x, frame_y, frame_width, frame_height)
        local sprite
        if output_sprite == DEFAULT_OUTPUT_SPRITE then
            sprite = original_sprite
            clear_sprite(sprite)
            sprite:resize(map_width, map_height)
        else
            sprite = create_sprite_set_palette(map_width, map_height, palette)
        end
        duplicate_image_on_sprite(sprite, frame_image, frames_count, max_frames_in_line, frame_width, frame_height)
    else
        local image = Image(map_width, map_height)
        put_frames_on_image(image, original_sprite, frames_count, max_frames_in_line, frame_x, frame_y, frame_width, frame_height)
        put_image_on_sprite(create_sprite_set_palette(map_width, map_height, palette), image, Point(0, 0))
    end
end

local function set_values(x, y, width, height, frames_count)
    local data = dialog.data
    data.x = x
    data.y = y
    data.width = width
    data.height = height
    data.frames_count = frames_count or data.frames_count
    dialog.data = data
end

local function set_default_values()
    local sprite = app.activeSprite
    if sprite == nil then
        return
    end
    set_values(0, 0, sprite.width, sprite.height, #sprite.frames)
end

dialog:button({
    text = "From selection",
    onclick = function()
        local sprite = app.activeSprite
        if sprite == nil then 
            show_no_active_sprite_allert()
            return
        end
        local bounds = sprite.selection.bounds
        set_values(bounds.x, bounds.y, bounds.width, bounds.height, nil)
    end
})

dialog:button({
    text = "Default bounds",
    onclick = set_default_values
})

dialog:button({
    text = "Create",
    onclick = create_sprite_map
})

app.events:on("sitechange", set_default_values)

set_default_values()
dialog:show()