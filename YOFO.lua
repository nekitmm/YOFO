-- YOFO
-- Repeatable astro focusing
------------------------------ constants --------------------------------------
_MAX_POS = 1000
_PRESETS_FILENAME = "ML/SCRIPTS/yofo_settings/presets.lua"
_SCAN_LOG_FILENAME = "ML/SCRIPTS/yofo_scans/scan_logs.lua"
_TEST_LOG_FILENAME = "ML/LOGS/YOFOTEST.LOG"
----------------------------- helpers -----------------------------------------
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

    local settings = loadfile(_PRESETS_FILENAME)
    local default = {["RGB"] = 0, ["Ha"] = 0}

    if not settings then
        settings = function() return {[lens.name] = default} end
    end

    settings = settings()
    if not settings[lens.name] then settings[lens.name] = default end

    return settings
end

function saveFile(settings) table.save(settings, _PRESETS_FILENAME) end

function printf(s, ...)
    test_log:writef(s, ...)
    if not console.visible then display.notify_box(s:format(...), 5000) end
end

function request_mode(mode, mode_str)
    if camera.mode ~= mode or not camera.gui.idle then
        printf("Please switch to %s mode.\n", mode_str, mode)

        while camera.mode ~= mode or not camera.gui.idle do
            console.show();
            assert(console.visible)
            if camera.gui.idle then alert() end
            sleep(1)
        end
    end
    sleep(2)
end

----------------------------- body -----------------------------------------

require("logger")
test_log = nil
test_log = logger(_TEST_LOG_FILENAME)

scan_log = nil

yofo = {}
yofo.value = ""
yofo.presets = {"RGB", "Ha"}
yofo.num_presets = #(yofo.presets)
yofo.settings = table.load()
yofo.current_position = 0

function move_focus(steps)
    if not lv.running then
        print("Please turn on LiveView first!")
        return
    end
    if not lens.af then
        print("Please turn on Autofocus!")
        return
    end
    print("Moving to " .. steps .. ".")
    lens.focus(steps, 1, true, true)
end

----------------------------- goto menu ---------------------------------------

function gotoRGB()
    local preset = yofo.presets_menu.submenu["RGB"].value
    menu.close()
    if not lv.running then lv.start() end
    move_focus(preset)
    lv.stop()
    menu.open()
end

function gotoHa()
    local preset = yofo.presets_menu.submenu["Ha"].value
    menu.close()
    if not lv.running then lv.start() end
    move_focus(preset)
    lv.stop()
    menu.open()
end

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
            select = function(this) task.create(gotoRGB) end
        }, {
            name = "Ha",
            help = "Infinity point for Hydrogen filter",
            update = function(this)
                return yofo.presets_menu.submenu["Ha"].value
            end,
            select = function(this) task.create(gotoHa) end
        }
    },
    update = function(this) return "" end
}

----------------------------- presets menu ------------------------------------

yofo.presets_menu = menu.new {
    parent = "Focus",
    name = "YOFO Presets",
    help = "Manage infinity presets for this lens (" .. lens.name .. ")",
    submenu = {
        {
            name = "RGB",
            help = "Infinity point for RGB frames",
            min = 0,
            max = _MAX_POS,
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
            max = _MAX_POS,
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

----------------------------- scan menu ---------------------------------------

function run_scan()
    print("Scan start...")

    scan_log = logger(_SCAN_LOG_FILENAME)

    menu.close()

    local start_pos = yofo.scan_menu.submenu["Start"].value
    local end_pos = yofo.scan_menu.submenu["End"].value
    local step = yofo.scan_menu.submenu["Step"].value

    local image_path = nil
    local image_prefix = nil
    local position = 0
    local num_frames = (end_pos - start_pos) // step + 1
    local curr_frame = 0

    dryos.image_prefix = "YOF_"

    if not lv.running then lv.start() end
    move_focus(start_pos)
    yofo.current_position = start_pos

    position = start_pos
    while position <= end_pos do
        curr_frame = curr_frame + 1
        print("Scanning position " .. position .. "!")

        image_path = dryos.shooting_card:image_path(1)
        scan_log:writef(image_path .. " " .. position .. "\n")

        camera.shoot(false)
        lv.start()
        print("Moving to the next step!")
        position = position + step
        move_focus(step)
        yofo.current_position = position
    end

    dryos.image_prefix = ""
    lv.stop()
    display.on()
    menu.open()
    scan_log:close()
end

yofo.scan_menu = menu.new {
    parent = "Focus",
    name = "YOFO Scan",
    help = "Scan through range to find best position",
    submenu = {
        {
            name = "Start",
            help = "Starting position",
            min = 0,
            max = _MAX_POS,
            value = 0,
            unit = UNIT.DEC
        }, {
            name = "End",
            help = "End position, must be greater than Start",
            min = 0,
            max = _MAX_POS,
            value = 30,
            unit = UNIT.DEC
        }, {
            name = "Step",
            help = "Interval step",
            min = 1,
            max = 100,
            value = 10,
            unit = UNIT.DEC
        }, {
            name = "Run",
            help = "Run scan using current settings",
            update = function(this) return "" end,
            select = function(this) task.create(run_scan) end
        }
    },
    depends_on = DEPENDS_ON.AUTOFOCUS,
    update = function(this) return "" end
}

----------------------- focus position menu -----------------------------------

yofo.focus_menu = menu.new {
    parent = "Focus",
    name = "YOFO Position*",
    help = "Current absolute focuser motor position",
    warning = function(this) return "*Trust with care!" end,
    update = function(this) return yofo.current_position end
}
yofo.focus_menu.select = function(this)
    local s = menu.get("Focus", "Focus End Point")
    local offset = 0

    if s ~= "0 (here)" then
        local sign, value = s:match("(.)(%d+).+")
        if sign == "-" then
            offset = -tonumber(value)
        else
            offset = tonumber(value)
        end
    end
    this.rinfo = "-> " .. (yofo.current_position + offset)
end

