-- loader.lua
-- Auto-update loader for Ultimate Script

local function LoadUltimateLib()
    local GitHubURL = "https://raw.githubusercontent.com/[USERNAME]/UltimateScript/main/UltimateLib.lua"
    local PastebinBackup = "https://pastebin.com/raw/[PASTEBIN_CODE]"
    
    print("🚀 Loading Ultimate Script Library...")
    
    -- Try GitHub first
    local success, result = pcall(function()
        local lib = loadstring(game:HttpGet(GitHubURL, true))()
        if lib and lib.Version then
            print("✅ Loaded from GitHub - Version: " .. lib.Version)
            return lib
        end
    end)
    
    if success and result then
        return result
    end
    
    -- Fallback to Pastebin
    print("⚠️ GitHub failed, using Pastebin backup...")
    local success2, result2 = pcall(function()
        return loadstring(game:HttpGet(PastebinBackup))()
    end)
    
    if success2 and result2 then
        print("✅ Loaded from Pastebin backup")
        return result2
    else
        error("❌ Failed to load Ultimate Script from all sources")
    end
end

return LoadUltimateLib()