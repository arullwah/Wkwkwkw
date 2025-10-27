-- loader.lua
local function LoadUltimateLib()
    local GitHubURL = "https://raw.githubusercontent.com/arullwah/Wkwkwkw/main/LIBRARY.lua"
    
    print("🚀 Loading Ultimate Script Library...")
    
    local success, result = pcall(function()
        local lib = loadstring(game:HttpGet(GitHubURL, true))()
        if lib and lib.Version then
            print("✅ Loaded successfully - Version: " .. lib.Version)
            return lib
        end
    end)
    
    if success and result then
        return result
    else
        error("❌ Failed to load library")
    end
end

return LoadUltimateLib()
