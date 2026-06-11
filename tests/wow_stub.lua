-- tests/wow_stub.lua — the WoW API surface Decision.lua touches, backed by a
-- fixture registry. GetItemInfo/GetItemStats are plain globals in the client,
-- so installing test doubles is just defining them before the modules run.
--
-- Registry layering: `fixtures` is the pristine generated corpus (never
-- mutated); `overlay` holds per-case synthetic entries and overrides, cleared
-- by reset() between cases.

local Stub = {}

Stub.fixtures = {}
Stub.overlay = {}

-- Same pattern Decision.lua uses to resolve the itemID (lowercase "item:").
local function idFromLink(link)
    return tonumber(tostring(link):match("item:(%d+)"))
end

function Stub.get(id)
    return Stub.overlay[id] or Stub.fixtures[id]
end

local function lookup(link)
    local id = idFromLink(link)
    return id and Stub.get(id) or nil
end

function Stub.add(id, rec)
    Stub.overlay[id] = rec
end

function Stub.reset()
    Stub.overlay = {}
end

function Stub.install()
    -- Registry miss returns nothing — an uncached item, which is exactly the
    -- shape that drives Decision's DEFER path.
    function GetItemInfo(link)
        local rec = lookup(link)
        if not rec then return end
        return rec.name, link, rec.quality, rec.ilvl, nil,
               rec.itemType, rec.itemSubType, nil, rec.equipLoc,
               nil, nil, rec.classID, rec.subclassID
    end

    function GetItemStats(link)
        local rec = lookup(link)
        return rec and rec.stats or nil
    end
end

return Stub
