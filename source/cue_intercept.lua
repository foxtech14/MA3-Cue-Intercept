-- BBLX Cue Intercept Plugin v2
-- By Michael Fox

-- ****************************************************************
-- local plugin variables
-- ****************************************************************

local pluginName = select(1, ...);
local pluginComponent = select(2, ...);
local signals = select(3, ...);
local handles = select(4, ...);

-- global function cache
local MB = MessageBox;
local PI = PopupInput;

 -- function lookup table
local functions = {}

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
    if (i == 0) then return t; end
    return t[i]
end

local function clamp(input, min, max)
    local ErrorString = "clamp(number:input, number:min, number:max) ";
    assert(type(input) == "number", ErrorString .. "- input, must be a number");
    assert(type(min) == "number", ErrorString .. "- min, must be a number");
    assert(type(max) == "number", ErrorString .. "- max, must be a number");
    assert(min <= max, ErrorString .. "- min must be less or equal to max");
    local i = input;
    if i < min then i = min end
    if i > max then i = max end
    return i;
end

-- ****************************************************************
-- worker functions
-- ****************************************************************

-- local function findQ(array, target, low, high, lower)
--     while low < high do
--         local middle = math.floor((low + high)/2); -- find the middle cue number as a rounded integer
--         local q = array[middle]; -- get the middle array element
--         local i = q.no; -- get the cue number of the middle q

--         -- if cue nubmers match return the cue number
--         if (i == target) then return i, true; end

--         if (i > target) then
--             -- if current middle is larger than target Q
--             high = middle - 1; -- set the middle as the new high
--         end

--         if (i < target) then
--             -- if current middle is smaller than target Q
--             low = middle + 1; -- set the middle as the new low
--             lower = i; -- set lower as current lowest Q
--         end
--     end

--     return lower, false;
-- end

local function findQ(array, target, first, last, lower)
    if (first > last) then return lower, false; end

    local middle = math.floor((first + last)/2);
    local q = array[middle];
    local i = q.no;

    if (i == target) then return i, true; end
    if (i > target) then return findQ(array, target, first, middle-1, lower); end
    if (i < target) then return findQ(array, target, middle+1, last, i); end
end

-- ****************************************************************
-- config functions
-- ****************************************************************

local function createMacros()
    -- input dialog for user input for cue number
    local macroNum = MB({
        title = "Start Macro number?",
        commands = {{value = 1, name = "Ok"},{value = 0, name = "Skip"}},
        inputs = {{name = "Macro", whiteFilter = "0123456789"}},
        backColor = "Global.Default",
        icon = "logo_small",
    });

    if macroNum.result == 1 then
        -- convert user input
        local num = clamp(tonumber(macroNum.inputs['Macro']), 1, 9999);
        local cmd1 = 'Call Plugin "BBLX Cue Intercept" "execute"';

        C("Store Macro %s.1", num);
        C("Set Macro %s.1 Property 'Command' '%s'", num, cmd1);
        C("Label Macro %s '%s'", num, "Run Q Intercept");
    end
end

local function uninstall()
    if Confirm("Uninstall?", "Do you want to Uninstall?") then
        DelVar(GlobalVars(),"bbCI_lead");
        DelVar(GlobalVars(),"bbCI_osc");
        DelVar(GlobalVars(),"bbCI_oos");
        C("Delete Macro 'BBLX Cue Intercept'");
    end
end

local function config()
    local functions = {
        [1] = createMacros,
        [2] = uninstall,
    };

    local i,t = PI({
        title = "Config",
        caller = GetFocusDisplay(),
        items = {"Create Macros","Uninstall"}
    });

    if not isempty(i) then
        local func = functions[i];
        if(func) then func(); end
    end
end

-- ****************************************************************
-- main functions
-- ****************************************************************

functions['updateTriggers'] = function ()
    local ciLead = GetVar(GlobalVars(),'bbCI_lead');
    local object = ObjectList(string.format("Sequence %s", ciLead));
    local seq = object[1];

    local qF = seq[3]; -- get the first q
    local first = qF.no/1000;

    local qL = seq[seq.count]; -- get the last q
    local last = qL.no/1000;

    C("Set Sequence %s Cue %s Thru %s Part 0 Property 'Command' 'Call Macro \"Run Q Intercept\"'", ciLead, first, last);
end

functions['execute'] = function()
    local ciLead = GetVar(GlobalVars(),'bbCI_lead');
    local oscPath = GetVar(GlobalVars(),'bbCI_osc');
    local oosList = GetVar(GlobalVars(),'bbCI_oos');

    local object = ObjectList(string.format("Sequence %s", ciLead));
    local seq = object[1];
    local cueTX = seq:CurrentChild();

    if (oscPath ~= "0") then
        -- CueTX.no = Q num x1000
        local oscNum = cueTX.no/1000; -- Floating point Cue Number
        local paths = spiltString(oscPath, ",", 0);
        for i, p in pairs(paths) do
            C("SendOSC %s '/out/cue,fs,%s,%s'",p,oscNum,cueTX.name);
        end
    end

    if oosList == "0" then return end
    local oosSeq = spiltString(oosList, ",", 0);
    local found, exact;

    for i,v in pairs(oosSeq) do
        object = ObjectList(string.format("Sequence %s", v));
        seq = object[1];
        local current = seq:CurrentChild();

        found, exact = findQ(seq, cueTX.no, 1, seq.count, 0);
        if (current == nil) or (found ~= current.no) then
            C("Goto Sequence %s Cue %s", v, found/1000);
        end
    end
end

functions['config'] = function()
    -- Get the index of the display on which to create the dialog.
    local displayIndex = Obj.Index(GetFocusDisplay());
    if displayIndex > 5 then displayIndex = 1; end
    -- Get the overlay.
    local display = GetDisplayByIndex(displayIndex);
    local screenOverlay = display.ScreenOverlay;
    screenOverlay:ClearUIChildren(); -- Delete any UI elements currently displayed on the overlay.
    local window = screenOverlay:Append("BaseInput"); -- Create Window Base

    local titleBar = window:Append("TitleBar");
    local titleButton = titleBar:Append("TitleButton");
    local configButton = titleBar:Append("TitleButton");
    local closeButton = titleBar:Append("CloseButton");

    local dialogFrame = window:Append("DialogFrame");
    local subFrame = dialogFrame:Append("UILayoutGrid");

    local oscTitle = subFrame:Append("UIObject");
    local oscPatch = subFrame:Append("LineEdit");
    local leadTitle = subFrame:Append("UIObject");
    local leadText = subFrame:Append("LineEdit");

    local oosTitle = dialogFrame:Append("UIObject");
    local oosList = dialogFrame:Append("LineEdit");
    local saveButton = dialogFrame:Append("Button");

    local function displayConfig()
        -- Create the dialog base.
        local dialogWidth = 600
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
        titleBar.Columns = 3;
        titleBar.Rows = 1;
        titleBar.Anchors = "0,0";
        titleBar[2][2].SizePolicy = "Fixed";
        titleBar[2][2].Size = "50";
        titleBar[2][3].SizePolicy = "Fixed";
        titleBar[2][3].Size = "50";
        titleBar.Texture = "corner1";

        titleButton.Text = "Cue Intercept Config";
        titleButton.Texture = "corner1";
        titleButton.Anchors = "0,0";
        titleButton.Icon = "object_sequence";

        configButton.Anchors = "1,0";
        configButton.Icon = "setup";
        configButton.HasHover = "Yes"
        configButton.PluginComponent = handles

        closeButton.Anchors = "2,0";
        closeButton.Texture = "corner2";

        -- Create the dialog's main frame.
        dialogFrame.H = "100%";
        dialogFrame.W = "100%";
        dialogFrame.Columns = 1;
        dialogFrame.Rows = 4;
        dialogFrame.Anchors = "0,1"
        dialogFrame[1][1].SizePolicy = "Fixed";
        dialogFrame[1][1].Size = "125";
        dialogFrame[1][2].SizePolicy = "Fixed";
        dialogFrame[1][2].Size = "75";
        dialogFrame[1][3].SizePolicy = "Fixed";
        dialogFrame[1][3].Size = "50";
        dialogFrame[1][4].SizePolicy = "Fixed";
        dialogFrame[1][4].Size = "125";

        -- Create the dialog's sub frame.
        subFrame.Columns = 2;
        subFrame.Rows = 2;
        subFrame.Anchors = "0,0"
        subFrame[1][1].SizePolicy = "Fixed";
        subFrame[1][1].Size = "75";
        subFrame[1][2].SizePolicy = "Fixed";
        subFrame[1][2].Size = "50";

        -- Create a sub title.
        -- This is row 1 col 1 of the sub frame.
        leadTitle.Text = "Lead Sequence"
        leadTitle.ContentDriven = "Yes"
        leadTitle.ContentWidth = "No"
        leadTitle.TextAutoAdjust = "No"
        leadTitle.Anchors = "0,0"
        leadTitle.Padding = {
            left = 0,
            right = 0,
            top = 25,
            bottom = 0
        }
        leadTitle.Font = "Medium20"
        leadTitle.HasHover = "No"
        leadTitle.BackColor = Root().ColorTheme.ColorGroups.Global.Transparent

        -- Create a Number Input.
        -- This is row 2 col 1 of the sub frame.
        leadText.Prompt = "Lead: "
        leadText.TextAutoAdjust = "Yes"
        leadText.Anchors = "0,1"
        leadText.Margin = {
            left = 12,
            right = 25,
            top = 0,
            bottom = 0
        }
        leadText.Padding = "5,5"
        leadText.Font = "Regular20"
        leadText.Filter = "0123456789,"
        leadText.VkPluginName = "TextInput"
        leadText.Content = GetVar(GlobalVars(),'bbCI_lead');
        leadText.HideFocusFrame = "Yes"
        leadText.PluginComponent = handles

        -- Create a sub title.
        -- This is row 1 col 2 of the sub frame.
        oscTitle.Text = "OSC TX Patch"
        oscTitle.ContentDriven = "Yes"
        oscTitle.ContentWidth = "No"
        oscTitle.TextAutoAdjust = "No"
        oscTitle.Anchors = "1,0"
        oscTitle.Padding = {
            left = 0,
            right = 0,
            top = 25,
            bottom = 0
        }
        oscTitle.Font = "Medium20"
        oscTitle.HasHover = "No"
        oscTitle.BackColor = Root().ColorTheme.ColorGroups.Global.Transparent

        -- Create a Number Input.
        -- This is row 2 col 2 of the sub frame.
        oscPatch.Prompt = "OSC Patch: "
        oscPatch.TextAutoAdjust = "Yes"
        oscPatch.Anchors = "1,1"
        oscPatch.Margin = {
            left = 25,
            right = 12,
            top = 0,
            bottom = 0
        }
        oscPatch.Padding = "5,5"
        oscPatch.Font = "Regular20"
        oscPatch.Filter = "0123456789,"
        oscPatch.VkPluginName = "TextInput"
        oscPatch.Content = GetVar(GlobalVars(),'bbCI_osc');
        oscPatch.HideFocusFrame = "Yes"
        oscPatch.PluginComponent = handles

        -- Create a sub title.
        -- This is row 2 of the dialogFrame.
        oosTitle.Text = "OOS Seq List"
        oosTitle.ContentDriven = "Yes"
        oosTitle.ContentWidth = "No"
        oosTitle.TextAutoAdjust = "No"
        oosTitle.Anchors = "0,1"
        oosTitle.Padding = {
            left = 0,
            right = 0,
            top = 25,
            bottom = 0
        }
        oosTitle.Font = "Medium20"
        oosTitle.HasHover = "No"
        oosTitle.BackColor = Root().ColorTheme.ColorGroups.Global.Transparent

        -- Create a Number Input.
        -- This is row 3 of the dialogFrame.
        oosList.Prompt = "Sequences: "
        oosList.TextAutoAdjust = "Yes"
        oosList.Anchors = "0,2"
        oosList.Margin = {
            left = 25,
            right = 25,
            top = 0,
            bottom = 0
        }
        oosList.Padding = "5,5"
        oosList.Font = "Regular20"
        oosList.Filter = "0123456789,"
        oosList.VkPluginName = "TextInput"
        oosList.Content = GetVar(GlobalVars(),'bbCI_oos');
        oosList.HideFocusFrame = "Yes"
        oosList.PluginComponent = handles

        saveButton.Anchors = "0,3"
        saveButton.Margin = {
            left = 0,
            right = 0,
            top = 50,
            bottom = 0
        }
        saveButton.Textshadow = 1;
        saveButton.HasHover = "Yes";
        saveButton.Text = "Save";
        saveButton.Font = "Medium20";
        saveButton.TextalignmentH = "Centre";
        saveButton.PluginComponent = handles

    end

    displayConfig();

    configButton.Clicked = "ConfigButtonClicked";
    saveButton.Clicked = "SaveButtonClicked";

    -- Handlers
    signals.ConfigButtonClicked = function()
        config()
    end

    signals.SaveButtonClicked = function()
        SetVar(GlobalVars(),'bbCI_lead', leadText.Content);
        E("Lead Seq Saved: %s", leadText.Content);
        SetVar(GlobalVars(),'bbCI_osc', oscPatch.Content);
        E("OSC Saved: %s", oscPatch.Content);
        SetVar(GlobalVars(),'bbCI_oos', oosList.Content);
        E("OOS Saved: %s", oosList.Content);
        Obj.Delete(screenOverlay, Obj.Index(window));
        E("Exited");
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