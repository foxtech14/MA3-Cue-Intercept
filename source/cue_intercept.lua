-- BBLX Cue Intercept Plugin v1
-- By Michael Fox

-- ****************************************************************
-- local plugin variables
-- ****************************************************************

local pluginName = select(1, ...);
local pluginComponent = select(2, ...);
local signals = select(3, ...);
local handles = select(4, ...);

 -- function lookup table
local functions = {}

-- maximum OOS sequences
local maxOOS = 8

-- ****************************************************************
-- helper functions
-- ****************************************************************

local function C(s, ...)
    Cmd(string.format(s, ...));
end

local function E(s, ...)
    Echo(string.format(s, ...));
end

local function isempty(s)
    return s == nil or s == ''
end

local function spiltString(inputstr, sep, i)
    local t = {}
    if sep == nil then sep = "%s" end
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t[i]
end

local function baseWindow()
    -- Get the index of the display on which to create the dialog.
    local displayIndex = Obj.Index(GetFocusDisplay())
    if displayIndex > 5 then
        displayIndex = 1
    end

    -- Get the overlay.
    local display = GetDisplayByIndex(displayIndex)
    local screenOverlay = display.ScreenOverlay

    -- Delete any UI elements currently displayed on the overlay.
    screenOverlay:ClearUIChildren()

    -- Create Window Base
    local window = screenOverlay:Append("BaseInput")
    return window, display
end

local function notInstalledWarning()
    MessageBox({
        title = "Warning",
        message = "Please install the Plugin before trying to configure anthing.",
        commands = {{value = 1, name = "Ok"}},
        icon = "logo_small",
    })
end

-- ****************************************************************
-- worker functions
-- ****************************************************************

local function sendOSC(num, name)
    C(string.format("SendOSC 1 '/out/cue,fs,%s,%s'",num,name))
end

local function findQ(array, target, first, last, lower)
    if (first > last) then return lower, false end

    local middle = math.floor((first + last)/2)
    local q = array[middle]
    local i = q.no

    if (i == target) then return i, true end

    if (i > target) then
        return findQ(array, target, first, middle-1, lower)
    end

    if (i < target) then
        return findQ(array, target, middle+1, last, i)
    end
end

-- ****************************************************************
-- main functions
-- ****************************************************************

functions['config'] = function()
    -- check to see if the plugin has been installed or not
    if (isempty(GetVar(GV, "bbInterceptInstalled"))) then
        notInstalledWarning()
        return
    end

    local window, display = baseWindow()

    local titleBar = window:Append("TitleBar")
    local titleButton = titleBar:Append("TitleButton")
    local closeButton = titleBar:Append("CloseButton")

    local dialogFrame = window:Append("DialogFrame")
    local oscEnable = dialogFrame:Append("CheckBox")
    local oosEnable = dialogFrame:Append("CheckBox")
    local finishButton = dialogFrame:Append("Button")

    local function displayConfig()
        -- Create the dialog base.
        local dialogWidth = 300
        window.Name = "Cue Intercept Config"
        window.H = "0"
        window.W = dialogWidth
        window.MaxSize = string.format("%s,%s", display.W * 0.8, display.H)
        window.MinSize = string.format("%s,0", dialogWidth - 100)
        window.Columns = 1
        window.Rows = 2
        window[1][1].SizePolicy = "Fixed"
        window[1][1].Size = "60"
        window[1][2].SizePolicy = "Stretch"
        window.AutoClose = "No"
        window.CloseOnEscape = "Yes"

        -- Create the title bar.
        titleBar.Columns = 2;
        titleBar.Rows = 1;
        titleBar.Anchors = "0,0";
        titleBar[2][2].SizePolicy = "Fixed";
        titleBar[2][2].Size = "50";
        titleBar.Texture = "corner1";

        titleButton.Text = "Cue Intercept Config";
        titleButton.Texture = "corner1";
        titleButton.Anchors = "0,0";
        titleButton.Icon = "object_fixture2";

        closeButton.Anchors = "1,0";
        closeButton.Texture = "corner2";

        -- Create the dialog's main frame.
        dialogFrame.H = "100%";
        dialogFrame.W = "100%";
        dialogFrame.Columns = 1;
        dialogFrame.Rows = 3;
        dialogFrame.Anchors = "0,1"
        dialogFrame[1][1].SizePolicy = "Fixed";
        dialogFrame[1][1].Size = "60";
        dialogFrame[1][2].SizePolicy = "Fixed";
        dialogFrame[1][2].Size = "60";
        dialogFrame[1][3].SizePolicy = "Fixed";
        dialogFrame[1][3].Size = "120";

        oscEnable.Anchors = "0,0"
        oscEnable.Margin = {
            left = 0,
            right = 0,
            top = 0,
            bottom = 0
        }
        oscEnable.Text = "OSC Enable"
        oscEnable.Tooltip = "OSC"
        oscEnable.TextalignmentH = "Left";
        oscEnable.State = 0;
        oscEnable.PluginComponent = handles
        oscEnable.ColorIndicator = Root().ColorTheme.ColorGroups.SystemMonitor.Green

        oosEnable.Anchors = "0,1"
        oosEnable.Margin = {
            left = 0,
            right = 0,
            top = 40,
            bottom = 0
        }
        oosEnable.Text = "OOS Enable"
        oosEnable.Tooltip = "OOS"
        oosEnable.TextalignmentH = "Left";
        oosEnable.State = 0;
        oosEnable.PluginComponent = handles
        oosEnable.ColorIndicator = Root().ColorTheme.ColorGroups.SystemMonitor.Yellow

        finishButton.Anchors = "0,2"
        finishButton.Margin = {
            left = 0,
            right = 0,
            top = 40,
            bottom = 0
        }
        finishButton.Textshadow = 1;
        finishButton.HasHover = "Yes";
        finishButton.Text = "Apply";
        finishButton.Font = "Medium20";
        finishButton.TextalignmentH = "Centre";
        finishButton.PluginComponent = handles

    end

    displayConfig()

    oscEnable.Clicked = "checkboxToggled"
    oosEnable.Clicked = "checkboxToggled"
    finishButton.Clicked = "FinishButtonClicked"

    -- Handlers
    signals.checkboxToggled = function(caller)
        caller.State = 1 - caller.State
        if (caller.State == 1) then SetVar(GV, "bbIntercept"..caller.Tooltip, "true") end
        if (caller.State == 0) then SetVar(GV, "bbIntercept"..caller.Tooltip, "false") end
    end

    signals.FinishButtonClicked = function(caller)
        Obj.Delete(screenOverlay, Obj.Index(window))
    end

end

functions['logic'] = function()
    local mySequence = SelectedSequence()
    local cueTX = mySequence:CurrentChild()

    local rawNum = cueTX.no -- MA integer cue number x1000
    local oscNum = cueTX.no/1000 -- Floating point Cue Number
    local cueName = cueTX.name -- Current selected sequence cue name

    local object, seq, found, exact

    if (useOSC) then sendOSC(oscNum, cueName) end

    if (not oosEnable) then
        return
    end

    for i,v in ipairs(oosSeq) do
        object = ObjectList(string.format("Sequence %s", v))
        seq = object[1]
        local current = seq:CurrentChild()
        found, exact = findQ(seq, rawNum, 1, seq.count, 1)

        if (current ~= nil) then
            if (found ~= current.no) then
                C(string.format("Goto Sequence %s Cue %s", v, found/1000))
            end
        end
    end
end

-- ****************************************************************
-- caller function
-- ****************************************************************

local function main(display,argument)
    if argument then
        functions[spiltString(argument,",",1)]()
    else
        functions['config']()
    end
end

return main;