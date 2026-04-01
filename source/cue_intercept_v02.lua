-- BBLX Cue Intercept Plugin v2
-- By Michael Fox

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

-- ****************************************************************
-- worker functions
-- ****************************************************************

local function sendOSC(out,num, name)
    C("SendOSC %s '/out/cue,fs,%s,%s'",out,num,name);
end

local function findQ(array, target, first, last, lower)
    -- if the search dataset flips then return lower bound as found q
    if (first > last) then return lower, false end

    local middle = math.floor((first + last)/2) -- find the middle cue number as a rounded integer
    local q = array[middle] -- get the middle array element
    local i = q.no -- get the cue number of the middle q

    -- if cue nubmers match return the cue number
    if (i == target) then return i, true end

    if (i > target) then
        -- if current middle is larger than target Q
        return findQ(array, target, first, middle-1, lower)
        -- search in first half of dataset and pass thorugh lower bound
    end

    if (i < target) then
        -- if current middle is smaller than target Q
        return findQ(array, target, middle+1, last, i)
        -- search in second half of dataset and set lower bound to current middle
    end
end

-- ****************************************************************
-- main functions
-- ****************************************************************

functions['logic'] = function()
    local mySequence = SelectedSequence();
    local cueTX = mySequence:CurrentChild();

    local rawNum = cueTX.no; -- MA integer cue number x1000
    local oscNum = cueTX.no/1000; -- Floating point Cue Number
    local cueName = cueTX.name; -- Current selected sequence cue name

    if (useOSC) then sendOSC(oscNum, cueName) end

    if (not oosEnable) then
        return
    end

    local found, exact;

    for i,v in ipairs(oosSeq) do
        local object = ObjectList(string.format("Sequence %s", v));
        local seq = object[1];
        local current = seq:CurrentChild();
        found, exact = findQ(seq, rawNum, 1, seq.count, 1);

        if (current ~= nil) then
            if (found ~= current.no) then
                C(string.format("Goto Sequence %s Cue %s", v, found/1000));
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