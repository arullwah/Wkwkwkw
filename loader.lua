-- loader.lua - FIXED VERSION
print("🔧 Ultimate Script Loader Starting...")

local function LoadLibrary()
    local GitHubURL = "https://raw.githubusercontent.com/arullwah/Wkwkwkw/refs/heads/main/library.lua"
    
    print("📥 Downloading from GitHub...")
    
    -- Download library
    local libraryCode = game:HttpGet(GitHubURL)
    
    if not libraryCode or libraryCode == "" then
        error("❌ Failed to download library from GitHub")
    end
    
    print("✅ Library downloaded successfully")
    
    -- Load library
    local success, library = pcall(function()
        return loadstring(libraryCode)()
    end)
    
    if not success then
        error("❌ Failed to load library: " .. tostring(library))
    end
    
    if not library then
        error("❌ Library returned nil")
    end
    
    if not library.LoadUI then
        error("❌ Library doesn't have LoadUI function")
    end
    
    print("🎯 Library loaded successfully!")
    return library
end

-- Main execution
local success, lib = pcall(LoadLibrary)

if success and lib then
    print("🚀 Launching Ultimate Script UI...")
    return lib:LoadUI()
else
    error("💥 Loader failed: " .. tostring(lib))
end