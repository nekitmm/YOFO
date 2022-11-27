-- YOFO
-- Repeatable astro focusing
function table.save(t, f)
    -- by @marcotrosi
    -- saves table t into file f

    local file, err = io.open(f, "wb")
    if err then
        print("Error writting file")
        return err
    end

    local function printTableHelper(obj, cnt)

        local cnt = cnt or 0

        if type(obj) == "table" then
            file:write("\n", string.rep("\t", cnt), "{\n")
            cnt = cnt + 1
            for k, v in pairs(obj) do
                if type(k) == "string" then
                    file:write(string.rep("\t", cnt), '["' .. k .. '"]', ' = ')
                end
                if type(k) == "number" then
                    file:write(string.rep("\t", cnt), "[" .. k .. "]", " = ")
                end
                printTableHelper(v, cnt)
                file:write(",\n")
            end
            cnt = cnt - 1
            file:write(string.rep("\t", cnt), "}")
        elseif type(obj) == "string" then
            file:write(string.format("%q", obj))
        else
            file:write(tostring(obj))
        end
    end

    file:write(
        "-- Focus Settings for YOFO.lua, please don't modify if you don't know what you're doing.\n")
    file:write(
        "-- Each value represents number steps that the autofocus motor has to go from hard limit to infinity.\n")
    file:write("return")
    printTableHelper(t)
    file:close()
end

function table:load()

    local settings = loadfile("ML/SCRIPTS/yofo_settings/presets.lua")
    local default = {["RGB"] = 0, ["Ha"] = 0}

    if not settings then
        settings = function() return {[lens.name] = default} end
    end

    settings = settings()
    if not settings[lens.name] then settings[lens.name] = default end

    return settings
end

function saveFile(settings)
    table.save(settings, "ML/SCRIPTS/yofo_settings/presets.lua")
end

function focus(current, position)
    if not lv.running then
        print("Please turn on LiveView first!")
        return
    end
    if not lens.af then
        print("Please turn on Autofocus!")
        return
    end
    print("Moving to " .. position .. ".")
    print("Do not touch the focus ring, this may take a while.")
    lens.focus(position, 1, true, true)
    print("You can now disable autofocus!")

    return position
end

-- body -----------------------------------------------------------------------------

yofo = {}
yofo.value = ""
yofo.presets = {"RGB", "Ha"}
yofo.num_presets = #(yofo.presets)
yofo.settings = table.load()
yofo.current_position = 0

yofo.goto_menu = menu.new {
    parent = "Focus",
    name = "YOFO Goto",
    help = "Focus this lens (" .. lens.name ..
        ") to infinity using preset positions.",
    submenu = {
        {
            name = "RGB",
            help = "Infinity point for RGB frames",
            update = function(this)
                return yofo.presets_menu.submenu["RGB"].value
            end,
            depends_on = DEPENDS_ON.LIVEVIEW
        }, {
            name = "Ha",
            help = "Infinity point for Hydrogen filter",
            update = function(this)
                return yofo.presets_menu.submenu["Ha"].value
            end,
            depends_on = DEPENDS_ON.LIVEVIEW
        }
    },
    depends_on = DEPENDS_ON.LIVEVIEW,
    update = function(this) return "" end
}

yofo.presets_menu = menu.new {
    parent = "Focus",
    name = "YOFO Presets",
    help = "Manage infinity presets for this lens (" .. lens.name .. ")",
    submenu = {
        {
            name = "RGB",
            help = "Infinity point for RGB frames",
            min = 0,
            max = 500,
            value = yofo.settings[lens.name]["RGB"],
            warning = function(this)
                if this.value ~= yofo.settings[lens.name]["RGB"] then
                    return "Don't forget to save changes!"
                end
            end,
            rinfo = function(this)
                if this.value ~= yofo.settings[lens.name]["RGB"] then
                    return "*"
                end
            end,
            unit = UNIT.DEC
        }, {
            name = "Ha",
            help = "Infinity point for Hydrogen filter",
            min = 0,
            max = 500,
            value = yofo.settings[lens.name]["Ha"],
            warning = function(this)
                if this.value ~= yofo.settings[lens.name]["Ha"] then
                    return "Don't forget to save changes!"
                end
            end,
            rinfo = function(this)
                if this.value ~= yofo.settings[lens.name]["Ha"] then
                    return "*"
                end
            end,
            unit = UNIT.DEC
        }, {
            name = "Save",
            help = "Save current settings to SD card",
            update = function(this) return "" end
        }
    },
    update = function(this) return "" end
}

----- focus position menu --------------------------

yofo.focus_menu = menu.new {
    parent = "Focus",
    name = "YOFO Position",
    help = "Current absolute focuser motor position",
    warning = function(this) return "Trust with care!" end,
    update = function(this) return yofo.current_position end
}
yofo.focus_menu.select = function(this)
    local s = menu.get("Focus", "Focus End Point")
    print("String:" .. s)
    local offset = 0
    if s ~= "0 (here)" then
        local sign, value = s:match("(.)(%d+).+")
        print("Match: " .. sign .. value)
        if sign == "-" then
            offset = -tonumber(value)
        else
            offset = tonumber(value)
        end
    end
    print("Final offset: " .. offset)
    this.rinfo = "-> " .. (yofo.current_position + offset)
end

----- presets menu --------------------------------

yofo.presets_menu.submenu["Save"].select = function(this)
    local lens_settings = {
        ["RGB"] = yofo.presets_menu.submenu["RGB"].value,
        ["Ha"] = yofo.presets_menu.submenu["Ha"].value
    }
    local settings = yofo.settings
    settings[lens.name] = lens_settings

    saveFile(settings)

    this.update = "Done!"
end

------- goto menu -------------------------------------

yofo.goto_menu.submenu["RGB"].select = function(this)
    local preset = yofo.presets_menu.submenu["RGB"].value
    local current = yofo.current_position
    yofo.current_position = focus(current, preset)
end

yofo.goto_menu.submenu["Ha"].select = function(this)
    local preset = yofo.presets_menu.submenu["Ha"].value
    local current = yofo.current_position
    yofo.current_position = focus(current, preset)
end
