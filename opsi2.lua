local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
wait(1)

-- ========= KONFIGURASI =========
local FPS_REKAMAN = 90
local FRAME_MAKSIMAL = 30000
local BATAS_JARAK_MINIMAL = 0.01
local SKALA_KECEPATAN = 1
local SKALA_KECEPATAN_Y = 1
local PENGGANDA_KECEPATAN_MUNDUR = 1.0
local PENGGANDA_KECEPATAN_MAJU = 1.0
local LANGKAH_FRAME_MUNDUR = 1
local LANGKAH_FRAME_MAJU = 1
local LANGKAH_DETIK_TIMELINE = 0.1
local COOLDOWN_GANTI_STATE = 0.1
local FRAME_TRANSISI = 5
local BATAS_JARAK_LANJUT = 40
local INTERVAL_WAKTU_TETAP = 1 / 90
local BATAS_KECEPATAN_LOMPAT = 10
local DURASI_TRANSISI_HALUS = 0.3

-- ========= PEMETAAN FIELD UNTUK OBFUSCATION =========
local PEMETAAN_FIELD = {
    Posisi = "11",
    VektorLihat = "88", 
    VektorAtas = "55",
    Kecepatan = "22",
    StateGerak = "33",
    KecepatanJalan = "44",
    Timestamp = "66"
}

local PEMETAAN_BALIK = {
    ["11"] = "Posisi",
    ["88"] = "VektorLihat",
    ["55"] = "VektorAtas", 
    ["22"] = "Kecepatan",
    ["33"] = "StateGerak",
    ["44"] = "KecepatanJalan",
    ["66"] = "Timestamp"
}

-- ========= VARIABEL =========
local SedangRekam = false
local SedangMain = false
local SedangJeda = false
local SedangMundur = false
local SedangMaju = false
local ModeTimeline = false
local KecepatanSekarang = 1
local KecepatanJalanSekarang = 16
local RekamanGerakan = {}
local UrutanRekaman = {}
local RekamanSekarang = {Frame = {}, WaktuMulai = 0, Nama = ""}
local AutoRespawn = false
local LompatTakTerbatas = false
local AutoLoop = false
local koneksiRekam = nil
local koneksiPutar = nil
local koneksiLoop = nil
local koneksiLompat = nil
local koneksiMundur = nil
local koneksiMaju = nil
local waktuRekamTerakhir = 0
local posisiRekamTerakhir = nil
local namaCheckpoint = {}
local VisualisasiJalur = {}
local TampilkanJalur = false
local PenandaJedaSekarang = nil
local waktuMulaiPutar = 0
local totalDurasiJeda = 0
local waktuMulaiJeda = 0
local framePutarSekarang = 1
local stateHumanoidSebelumJeda = nil
local kecepatanJalanSebelumJeda = 16
local autoRotateSebelumJeda = true
local kekuatanLompatSebelumJeda = 50
local platformStandSebelumJeda = false
local dudukSebelumJeda = false
local statePutarTerakhir = nil
local waktuGantiStateTerakhir = 0
local SedangAutoLoop = false
local IndexLoopSekarang = 1
local WaktuMulaiJedaLoop = 0
local TotalDurasiJedaLoop = 0
local koneksiShiftLock = nil
local perilakuMouseAsli = nil
local ShiftLockAktif = false
local isShiftLockActive = false
local StudioSedangRekam = false
local RekamanStudioSekarang = {Frame = {}, WaktuMulai = 0, Nama = ""}
local waktuRekamStudioTerakhir = 0
local posisiRekamStudioTerakhir = nil
local koneksiAktif = {}
local RekamanTercentang = {}
local FrameTimelineSekarang = 0
local PosisiTimeline = 0
local AutoReset = false
local RekamanYangDimainkan = nil
local DijedaDiFrame = 0
local akumulatorPutar = 0
local PosisiJedaTerakhir = nil
local RekamanJedaTerakhir = nil
local JarakRekamanTerdekat = math.huge

-- ========= EFEK SUARA =========
local EfekSuara = {
    Klik = "rbxassetid://4499400560",
    Toggle = "rbxassetid://7468131335", 
    RekamMulai = "rbxassetid://4499400560",
    RekamBerhenti = "rbxassetid://4499400560",
    Main = "rbxassetid://4499400560",
    Berhenti = "rbxassetid://4499400560",
    Error = "rbxassetid://7772283448",
    Sukses = "rbxassetid://2865227271"
}

local function TambahkanKoneksi(koneksi)
    table.insert(koneksiAktif, koneksi)
end

local function BersihkanKoneksi()
    for _, koneksi in ipairs(koneksiAktif) do
        if koneksi then
            koneksi:Disconnect()
        end
    end
    koneksiAktif = {}
    
    if koneksiRekam then koneksiRekam:Disconnect() koneksiRekam = nil end
    if koneksiPutar then koneksiPutar:Disconnect() koneksiPutar = nil end
    if koneksiLoop then koneksiLoop:Disconnect() koneksiLoop = nil end
    if koneksiShiftLock then koneksiShiftLock:Disconnect() koneksiShiftLock = nil end
    if koneksiLompat then koneksiLompat:Disconnect() koneksiLompat = nil end
    if koneksiMundur then koneksiMundur:Disconnect() koneksiMundur = nil end
    if koneksiMaju then koneksiMaju:Disconnect() koneksiMaju = nil end
end

local function MainkanSuara(jenisSuara)
    task.spawn(function()
        local suara = Instance.new("Sound")
        suara.SoundId = EfekSuara[jenisSuara] or EfekSuara.Klik
        suara.Volume = 0.3
        suara.Parent = workspace
        suara:Play()
        game:GetService("Debris"):AddItem(suara, 2)
    end)
end

local function AnimasiKlikTombol(tombol)
    MainkanSuara("Klik")
    local warnaAsli = tombol.BackgroundColor3
    local warnaLebihTerang = Color3.new(
        math.min(warnaAsli.R * 1.3, 1),
        math.min(warnaAsli.G * 1.3, 1), 
        math.min(warnaAsli.B * 1.3, 1)
    )
    
    TweenService:Create(tombol, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = warnaLebihTerang
    }):Play()
    
    wait(0.1)
    
    TweenService:Create(tombol, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = warnaAsli
    }):Play()
end

local function ResetKarakter()
    local karakter = player.Character
    if karakter then
        local humanoid = karakter:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Health = 0
        end
    end
end

local function TungguRespawn()
    local waktuMulai = tick()
    local batasWaktu = 10
    repeat
        task.wait(0.1)
        if tick() - waktuMulai > batasWaktu then return false end
    until player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0
    task.wait(1)
    return true
end

local function ApakahKarakterSiap()
    local karakter = player.Character
    if not karakter then return false end
    if not karakter:FindFirstChild("HumanoidRootPart") then return false end
    if not karakter:FindFirstChildOfClass("Humanoid") then return false end
    if karakter.Humanoid.Health <= 0 then return false end
    return true
end

local function ResetKarakterLengkap(karakter)
    if not karakter or not karakter:IsDescendantOf(workspace) then return end
    local humanoid = karakter:FindFirstChildOfClass("Humanoid")
    local hrp = karakter:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end
    task.spawn(function()
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = KecepatanJalanSekarang
        humanoid.JumpPower = kekuatanLompatSebelumJeda or 50
        humanoid.Sit = false
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end)
end

local function TerapkanShiftLockTerlihat()
    if not ShiftLockAktif or not player.Character then return end
    local karakter = player.Character
    local humanoid = karakter:FindFirstChildOfClass("Humanoid")
    local hrp = karakter:FindFirstChild("HumanoidRootPart")
    local kamera = workspace.CurrentCamera
    if humanoid and hrp and kamera then
        humanoid.AutoRotate = false
        local vektorLihat = kamera.CFrame.LookVector
        local lihatHorizontal = Vector3.new(vektorLihat.X, 0, vektorLihat.Z).Unit
        if lihatHorizontal.Magnitude > 0 then
            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + lihatHorizontal)
        end
    end
end

local function AktifkanShiftLockTerlihat()
    if koneksiShiftLock or not ShiftLockAktif then return end
    perilakuMouseAsli = UserInputService.MouseBehavior
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    isShiftLockActive = true
    koneksiShiftLock = RunService.RenderStepped:Connect(function()
        if ShiftLockAktif and player.Character then
            TerapkanShiftLockTerlihat()
        end
    end)
    TambahkanKoneksi(koneksiShiftLock)
    MainkanSuara("Toggle")
end

local function NonaktifkanShiftLockTerlihat()
    if koneksiShiftLock then
        koneksiShiftLock:Disconnect()
        koneksiShiftLock = nil
    end
    if perilakuMouseAsli then
        UserInputService.MouseBehavior = perilakuMouseAsli
    end
    local karakter = player.Character
    if karakter and karakter:FindFirstChildOfClass("Humanoid") then
        karakter.Humanoid.AutoRotate = true
    end
    isShiftLockActive = false
    MainkanSuara("Toggle")
end

local function ToggleShiftLockTerlihat()
    ShiftLockAktif = not ShiftLockAktif
    if ShiftLockAktif then
        AktifkanShiftLockTerlihat()
    else
        NonaktifkanShiftLockTerlihat()
    end
end

local function AktifkanLompatTakTerbatas()
    if koneksiLompat then return end
    koneksiLompat = UserInputService.JumpRequest:Connect(function()
        if LompatTakTerbatas and player.Character then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end)
    TambahkanKoneksi(koneksiLompat)
end

local function NonaktifkanLompatTakTerbatas()
    if koneksiLompat then
        koneksiLompat:Disconnect()
        koneksiLompat = nil
    end
end

local function ToggleLompatTakTerbatas()
    LompatTakTerbatas = not LompatTakTerbatas
    if LompatTakTerbatas then
        AktifkanLompatTakTerbatas()
    else
        NonaktifkanLompatTakTerbatas()
    end
end

local function SimpanStateHumanoid()
    local karakter = player.Character
    if not karakter then return end
    local humanoid = karakter:FindFirstChildOfClass("Humanoid")
    if humanoid then
        autoRotateSebelumJeda = humanoid.AutoRotate
        kecepatanJalanSebelumJeda = humanoid.WalkSpeed
        kekuatanLompatSebelumJeda = humanoid.JumpPower
        platformStandSebelumJeda = humanoid.PlatformStand
        dudukSebelumJeda = humanoid.Sit
        stateHumanoidSebelumJeda = humanoid:GetState()
        if stateHumanoidSebelumJeda == Enum.HumanoidStateType.Climbing then
            humanoid.PlatformStand = false
            humanoid.AutoRotate = false
        end
    end
end

local function KembalikanStateHumanoid()
    local karakter = player.Character
    if not karakter then return end
    local humanoid = karakter:FindFirstChildOfClass("Humanoid")
    if humanoid then
        if stateHumanoidSebelumJeda == Enum.HumanoidStateType.Climbing then
            humanoid.PlatformStand = false
            humanoid.AutoRotate = false
            humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
        else
            humanoid.AutoRotate = autoRotateSebelumJeda
            humanoid.WalkSpeed = kecepatanJalanSebelumJeda
            humanoid.JumpPower = kekuatanLompatSebelumJeda
            humanoid.PlatformStand = platformStandSebelumJeda
            humanoid.Sit = dudukSebelumJeda
        end
    end
end

local function KembalikanKontrolPenuh()
    local karakter = player.Character
    if not karakter then return end
    local humanoid = karakter:FindFirstChildOfClass("Humanoid")
    local hrp = karakter:FindFirstChild("HumanoidRootPart")
    if humanoid then
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = KecepatanJalanSekarang
        humanoid.JumpPower = kekuatanLompatSebelumJeda or 50
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
    if ShiftLockAktif then
        AktifkanShiftLockTerlihat()
    end
end

local function DapatkanStateGerakSekarang(hum)
    if not hum then return "Darat" end
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Climbing then return "Memanjat"
    elseif state == Enum.HumanoidStateType.Jumping then return "Melompat"
    elseif state == Enum.HumanoidStateType.Freefall then return "Jatuh"
    elseif state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics then return "Darat"
    elseif state == Enum.HumanoidStateType.Swimming then return "Berenang"
    else return "Darat" end
end

local function HapusVisualisasiJalur()
    for _, part in pairs(VisualisasiJalur) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    VisualisasiJalur = {}
    if PenandaJedaSekarang and PenandaJedaSekarang.Parent then
        PenandaJedaSekarang:Destroy()
        PenandaJedaSekarang = nil
    end
end

local function BuatSegmenJalur(posisiAwal, posisiAkhir, warna)
    local part = Instance.new("Part")
    part.Name = "SegmenJalur"
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.BrickColor = warna or BrickColor.new("Really black")
    part.Transparency = 0.2
    local jarak = (posisiAwal - posisiAkhir).Magnitude
    part.Size = Vector3.new(0.2, 0.2, jarak)
    part.CFrame = CFrame.lookAt((posisiAwal + posisiAkhir) / 2, posisiAkhir)
    part.Parent = workspace
    table.insert(VisualisasiJalur, part)
    return part
end

local function BuatPenandaJeda(posisi)
    if PenandaJedaSekarang and PenandaJedaSekarang.Parent then
        PenandaJedaSekarang:Destroy()
        PenandaJedaSekarang = nil
    end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PenandaJeda"
    billboard.Size = UDim2.new(0, 200, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "JEDA"
    label.TextColor3 = Color3.new(1, 1, 0)
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 18
    label.TextScaled = false
    label.Parent = billboard
    local part = Instance.new("Part")
    part.Name = "PartPenandaJeda"
    part.Anchored = true
    part.CanCollide = false
    part.Size = Vector3.new(0.1, 0.1, 0.1)
    part.Transparency = 1
    part.Position = posisi + Vector3.new(0, 2, 0)
    part.Parent = workspace
    billboard.Adornee = part
    billboard.Parent = part
    PenandaJedaSekarang = part
    return part
end

local function PerbaruiPenandaJeda()
    if SedangJeda then
        if not PenandaJedaSekarang then
            local karakter = player.Character
            if karakter and karakter:FindFirstChild("HumanoidRootPart") then
                local posisi = karakter.HumanoidRootPart.Position
                BuatPenandaJeda(posisi)
            end
        end
    else
        if PenandaJedaSekarang and PenandaJedaSekarang.Parent then
            PenandaJedaSekarang:Destroy()
            PenandaJedaSekarang = nil
        end
    end
end

local function ObfuscateDataRekaman(dataRekaman)
    local terobfuscate = {}
    for namaCheckpoint, frame in pairs(dataRekaman) do
        local frameTerobfuscate = {}
        for _, frame in ipairs(frame) do
            local frameTerobfuscate = {}
            for namaField, nilaiField in pairs(frame) do
                local kode = PEMETAAN_FIELD[namaField]
                if kode then
                    frameTerobfuscate[kode] = nilaiField
                else
                    frameTerobfuscate[namaField] = nilaiField
                end
            end
            table.insert(frameTerobfuscate, frameTerobfuscate)
        end
        terobfuscate[namaCheckpoint] = frameTerobfuscate
    end
    return terobfuscate
end

local function DeobfuscateDataRekaman(dataTerobfuscate)
    local terdeobfuscate = {}
    for namaCheckpoint, frame in pairs(dataTerobfuscate) do
        local frameTerdeobfuscate = {}
        for _, frame in ipairs(frame) do
            local frameTerdeobfuscate = {}
            for kode, nilaiField in pairs(frame) do
                local namaField = PEMETAAN_BALIK[kode]
                if namaField then
                    frameTerdeobfuscate[namaField] = nilaiField
                else
                    frameTerdeobfuscate[kode] = nilaiField
                end
            end
            table.insert(frameTerdeobfuscate, frameTerdeobfuscate)
        end
        terdeobfuscate[namaCheckpoint] = frameTerdeobfuscate
    end
    return terdeobfuscate
end

local function BuatTransisiHalus(frameTerakhir, framePertama, jumlahFrame)
    local frameTransisi = {}
    for i = 1, jumlahFrame do
        local alpha = i / (jumlahFrame + 1)
        local pos1 = Vector3.new(frameTerakhir.Posisi[1], frameTerakhir.Posisi[2], frameTerakhir.Posisi[3])
        local pos2 = Vector3.new(framePertama.Posisi[1], framePertama.Posisi[2], framePertama.Posisi[3])
        local posLerp = pos1:Lerp(pos2, alpha)
        local lihat1 = Vector3.new(frameTerakhir.VektorLihat[1], frameTerakhir.VektorLihat[2], frameTerakhir.VektorLihat[3])
        local lihat2 = Vector3.new(framePertama.VektorLihat[1], framePertama.VektorLihat[2], framePertama.VektorLihat[3])
        local lihatLerp = lihat1:Lerp(lihat2, alpha).Unit
        local atas1 = Vector3.new(frameTerakhir.VektorAtas[1], frameTerakhir.VektorAtas[2], frameTerakhir.VektorAtas[3])
        local atas2 = Vector3.new(framePertama.VektorAtas[1], framePertama.VektorAtas[2], framePertama.VektorAtas[3])
        local atasLerp = atas1:Lerp(atas2, alpha).Unit
        local vel1 = Vector3.new(frameTerakhir.Kecepatan[1], frameTerakhir.Kecepatan[2], frameTerakhir.Kecepatan[3])
        local vel2 = Vector3.new(framePertama.Kecepatan[1], framePertama.Kecepatan[2], framePertama.Kecepatan[3])
        local velLerp = vel1:Lerp(vel2, alpha)
        local kj1 = frameTerakhir.KecepatanJalan
        local kj2 = framePertama.KecepatanJalan
        local kjLerp = kj1 + (kj2 - kj1) * alpha
        table.insert(frameTransisi, {
            Posisi = {posLerp.X, posLerp.Y, posLerp.Z},
            VektorLihat = {lihatLerp.X, lihatLerp.Y, lihatLerp.Z},
            VektorAtas = {atasLerp.X, atasLerp.Y, atasLerp.Z},
            Kecepatan = {velLerp.X, velLerp.Y, velLerp.Z},
            StateGerak = frameTerakhir.StateGerak,
            KecepatanJalan = kjLerp,
            Timestamp = frameTerakhir.Timestamp + (i * 0.016)
        })
    end
    return frameTransisi
end

local function BuatRekamanGabungan()
    if #UrutanRekaman < 2 then
        MainkanSuara("Error")
        return
    end
    local frameGabungan = {}
    local totalOffsetWaktu = 0
    for _, namaCheckpoint in ipairs(UrutanRekaman) do
        local checkpoint = RekamanGerakan[namaCheckpoint]
        if not checkpoint then continue end
        if #frameGabungan > 0 and #checkpoint > 0 then
            local frameTerakhir = frameGabungan[#frameGabungan]
            local framePertama = checkpoint[1]
            local frameTransisi = BuatTransisiHalus(frameTerakhir, framePertama, FRAME_TRANSISI)
            for _, tFrame in ipairs(frameTransisi) do
                tFrame.Timestamp = tFrame.Timestamp + totalOffsetWaktu
                table.insert(frameGabungan, tFrame)
            end
            totalOffsetWaktu = totalOffsetWaktu + (FRAME_TRANSISI * 0.016)
        end
        for indexFrame, frame in ipairs(checkpoint) do
            local frameBaru = {
                Posisi = {frame.Posisi[1], frame.Posisi[2], frame.Posisi[3]},
                VektorLihat = {frame.VektorLihat[1], frame.VektorLihat[2], frame.VektorLihat[3]},
                VektorAtas = {frame.VektorAtas[1], frame.VektorAtas[2], frame.VektorAtas[3]},
                Kecepatan = {frame.Kecepatan[1], frame.Kecepatan[2], frame.Kecepatan[3]},
                StateGerak = frame.StateGerak,
                KecepatanJalan = frame.KecepatanJalan,
                Timestamp = frame.Timestamp + totalOffsetWaktu
            }
            table.insert(frameGabungan, frameBaru)
        end
        if #checkpoint > 0 then
            totalOffsetWaktu = totalOffsetWaktu + checkpoint[#checkpoint].Timestamp + 0.1
        end
    end
    local frameTeroptimasi = {}
    local frameSignifikanTerakhir = nil
    for i, frame in ipairs(frameGabungan) do
        local harusDimasukkan = true
        if frameSignifikanTerakhir then
            local pos1 = Vector3.new(frameSignifikanTerakhir.Posisi[1], frameSignifikanTerakhir.Posisi[2], frameSignifikanTerakhir.Posisi[3])
            local pos2 = Vector3.new(frame.Posisi[1], frame.Posisi[2], frame.Posisi[3])
            local jarak = (pos1 - pos2).Magnitude
            if jarak < 0.1 and frame.StateGerak == frameSignifikanTerakhir.StateGerak then
                harusDimasukkan = false
            end
        end
        if harusDimasukkan then
            table.insert(frameTeroptimasi, frame)
            frameSignifikanTerakhir = frame
        end
    end
    local namaGabungan = "gabungan_" .. os.date("%H%M%S")
    RekamanGerakan[namaGabungan] = frameTeroptimasi
    table.insert(UrutanRekaman, namaGabungan)
    namaCheckpoint[namaGabungan] = "GABUNGAN SEMUA"
    PerbaruiDaftarRekaman()
    MainkanSuara("Sukses")
end

local function DapatkanCFrameFrame(frame)
    local pos = Vector3.new(frame.Posisi[1], frame.Posisi[2], frame.Posisi[3])
    local lihat = Vector3.new(frame.VektorLihat[1], frame.VektorLihat[2], frame.VektorLihat[3])
    local atas = Vector3.new(frame.VektorAtas[1], frame.VektorAtas[2], frame.VektorAtas[3])
    return CFrame.lookAt(pos, pos + lihat, atas)
end

local function DapatkanKecepatanFrame(frame)
    return frame.Kecepatan and Vector3.new(
        frame.Kecepatan[1] * SKALA_KECEPATAN,
        frame.Kecepatan[2] * SKALA_KECEPATAN_Y,
        frame.Kecepatan[3] * SKALA_KECEPATAN
    ) or Vector3.new(0, 0, 0)
end

local function DapatkanKecepatanJalanFrame(frame)
    return frame.KecepatanJalan or 16
end

local function DapatkanTimestampFrame(frame)
    return frame.Timestamp or 0
end

local function DapatkanPosisiFrame(frame)
    return Vector3.new(frame.Posisi[1], frame.Posisi[2], frame.Posisi[3])
end

local function CariFrameTerdekat(rekaman, posisi)
    if not rekaman or #rekaman == 0 then return 1, math.huge end
    local frameTerdekat = 1
    local jarakTerdekat = math.huge
    for i, frame in ipairs(rekaman) do
        local posFrame = DapatkanPosisiFrame(frame)
        local jarak = (posFrame - posisi).Magnitude
        if jarak < jarakTerdekat then
            jarakTerdekat = jarak
            frameTerdekat = i
        end
    end
    return frameTerdekat, jarakTerdekat
end

-- ========= SISTEM PUTAR CERDAS =========
local function CariRekamanTerdekat(jarakMaks)
    local karakter = player.Character
    if not karakter or not karakter:FindFirstChild("HumanoidRootPart") then
        return nil, math.huge, nil
    end
    
    local posisiSekarang = karakter.HumanoidRootPart.Position
    local rekamanTerdekat = nil
    local jarakTerdekat = math.huge
    local namaTerdekat = nil
    
    for _, namaRekaman in ipairs(UrutanRekaman) do
        local rekaman = RekamanGerakan[namaRekaman]
        if rekaman and #rekaman > 0 then
            local frameTerdekat, jarakFrame = CariFrameTerdekat(rekaman, posisiSekarang)
            
            if jarakFrame < jarakTerdekat and jarakFrame <= (jarakMaks or 40) then
                jarakTerdekat = jarakFrame
                rekamanTerdekat = rekaman
                namaTerdekat = namaRekaman
            end
        end
    end
    
    return rekamanTerdekat, jarakTerdekat, namaTerdekat
end

local function PerbaruiStatusTombolPutar()
    local rekamanTerdekat, jarak = CariRekamanTerdekat(40)
    JarakRekamanTerdekat = jarak or math.huge
    
    if TombolPutarKontrol then
        if rekamanTerdekat and jarak <= 40 then
            TombolPutarKontrol.Text = "MAIN (" .. math.floor(jarak) .. "m)"
            TombolPutarKontrol.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
        else
            TombolPutarKontrol.Text = "MAIN"
            TombolPutarKontrol.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
        end
    end
end

-- ========= TRANSISI HALUS YANG DITINGKATKAN =========
local function BuatTransisiTingkatTinggi(posisiSekarang, frameTarget, durasi)
    local frameTransisi = {}
    local jumlahFrame = math.max(5, math.floor(durasi / INTERVAL_WAKTU_TETAP))
    
    local posTarget = DapatkanPosisiFrame(frameTarget)
    local cframeTarget = DapatkanCFrameFrame(frameTarget)
    local kecepatanTarget = DapatkanKecepatanFrame(frameTarget)
    
    for i = 1, jumlahFrame do
        local alpha = i / (jumlahFrame + 1)
        local alphaHalus = 1 - (1 - alpha) * (1 - alpha)
        
        local posLerp = posisiSekarang:Lerp(posTarget, alphaHalus)
        local lihatSekarang = (posTarget - posisiSekarang).Unit
        local lihatLerp = lihatSekarang:Lerp(cframeTarget.LookVector, alphaHalus).Unit
        local atasLerp = Vector3.new(0, 1, 0):Lerp(cframeTarget.UpVector, alphaHalus).Unit
        
        local kecepatanLerp = Vector3.new(0, 0, 0):Lerp(kecepatanTarget, alphaHalus)
        
        table.insert(frameTransisi, {
            Posisi = {posLerp.X, posLerp.Y, posLerp.Z},
            VektorLihat = {lihatLerp.X, lihatLerp.Y, lihatLerp.Z},
            VektorAtas = {atasLerp.X, atasLerp.Y, atasLerp.Z},
            Kecepatan = {kecepatanLerp.X, kecepatanLerp.Y, kecepatanLerp.Z},
            StateGerak = frameTarget.StateGerak,
            KecepatanJalan = DapatkanKecepatanJalanFrame(frameTarget),
            Timestamp = 0
        })
    end
    
    return frameTransisi
end

-- ========= MANAJEMEN STATE HUMANOID YANG DITINGKATKAN =========
local function ProsesStateHumanoid(hum, frame, stateTerakhir, waktuStateTerakhir)
    local stateGerak = frame.StateGerak
    local kecepatanFrame = DapatkanKecepatanFrame(frame)
    local waktuSekarang = tick()
    
    local sedangLompatDariKecepatan = kecepatanFrame.Y > BATAS_KECEPATAN_LOMPAT
    local sedangJatuhDariKecepatan = kecepatanFrame.Y < -5
    
    if sedangLompatDariKecepatan and stateGerak ~= "Melompat" then
        stateGerak = "Melompat"
    elseif sedangJatuhDariKecepatan and stateGerak ~= "Jatuh" then
        stateGerak = "Jatuh"
    end
    
    if stateGerak == "Melompat" then
        if stateTerakhir ~= "Melompat" then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            return "Melompat", waktuSekarang
        end
    elseif stateGerak == "Jatuh" then
        if stateTerakhir ~= "Jatuh" then
            hum:ChangeState(Enum.HumanoidStateType.Freefall)
            return "Jatuh", waktuSekarang
        end
    else
        if stateGerak ~= stateTerakhir and (waktuSekarang - waktuStateTerakhir) >= COOLDOWN_GANTI_STATE then
            if stateGerak == "Memanjat" then
                hum:ChangeState(Enum.HumanoidStateType.Climbing)
                hum.PlatformStand = false
                hum.AutoRotate = false
            elseif stateGerak == "Berenang" then
                hum:ChangeState(Enum.HumanoidStateType.Swimming)
            else
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
            return stateGerak, waktuSekarang
        end
    end
    
    return stateTerakhir, waktuStateTerakhir
end

-- ========= SETUP GUI =========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoWalkByaruL"
ScreenGui.ResetOnSpawn = false
if player:FindFirstChild("PlayerGui") then
    ScreenGui.Parent = player.PlayerGui
else
    wait(2)
    ScreenGui.Parent = player:WaitForChild("PlayerGui")
end

-- ========= GUI STUDIO REKAMAN (160x100) =========
local StudioRekaman = Instance.new("Frame")
StudioRekaman.Size = UDim2.fromOffset(160, 100)
StudioRekaman.Position = UDim2.new(0.5, -80, 0.5, -50)
StudioRekaman.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
StudioRekaman.BorderSizePixel = 0
StudioRekaman.Active = true
StudioRekaman.Draggable = true
StudioRekaman.Visible = false
StudioRekaman.Parent = ScreenGui

local SudutStudio = Instance.new("UICorner")
SudutStudio.CornerRadius = UDim.new(0, 8)
SudutStudio.Parent = StudioRekaman

local HeaderStudio = Instance.new("Frame")
HeaderStudio.Size = UDim2.new(1, 0, 0, 20)
HeaderStudio.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
HeaderStudio.BorderSizePixel = 0
HeaderStudio.Parent = StudioRekaman

local SudutHeaderStudio = Instance.new("UICorner")
SudutHeaderStudio.CornerRadius = UDim.new(0, 8)
SudutHeaderStudio.Parent = HeaderStudio

local JudulStudio = Instance.new("TextLabel")
JudulStudio.Size = UDim2.new(1, -30, 1, 0)
JudulStudio.BackgroundTransparency = 1
JudulStudio.Text = ""
JudulStudio.TextColor3 = Color3.fromRGB(255, 255, 255)
JudulStudio.Font = Enum.Font.GothamBold
JudulStudio.TextSize = 10
JudulStudio.Parent = HeaderStudio

local TombolTutupStudio = Instance.new("TextButton")
TombolTutupStudio.Size = UDim2.fromOffset(18, 18)
TombolTutupStudio.Position = UDim2.new(1, -20, 0.5, -9)
TombolTutupStudio.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
TombolTutupStudio.Text = "×"
TombolTutupStudio.TextColor3 = Color3.new(1, 1, 1)
TombolTutupStudio.Font = Enum.Font.GothamBold
TombolTutupStudio.TextSize = 14
TombolTutupStudio.Parent = HeaderStudio

local SudutTutupStudio = Instance.new("UICorner")
SudutTutupStudio.CornerRadius = UDim.new(0, 4)
SudutTutupStudio.Parent = TombolTutupStudio

local KontenStudio = Instance.new("Frame")
KontenStudio.Size = UDim2.new(1, -10, 1, -25)
KontenStudio.Position = UDim2.new(0, 5, 0, 22)
KontenStudio.BackgroundTransparency = 1
KontenStudio.Parent = StudioRekaman

local LEDRekaman = Instance.new("Frame")
LEDRekaman.Size = UDim2.fromOffset(8, 8)
LEDRekaman.Position = UDim2.new(0, 5, 0, 5)
LEDRekaman.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
LEDRekaman.BorderSizePixel = 0
LEDRekaman.Visible = false
LEDRekaman.Parent = HeaderStudio

local SudutLED = Instance.new("UICorner")
SudutLED.CornerRadius = UDim.new(1, 0)
SudutLED.Parent = LEDRekaman

local function BuatTombolStudio(teks, x, y, w, h, warna)
    local tombol = Instance.new("TextButton")
    tombol.Size = UDim2.fromOffset(w, h)
    tombol.Position = UDim2.fromOffset(x, y)
    tombol.BackgroundColor3 = warna
    tombol.Text = teks
    tombol.TextColor3 = Color3.new(1, 1, 1)
    tombol.Font = Enum.Font.GothamBold
    tombol.TextSize = 12
    tombol.AutoButtonColor = false
    tombol.Parent = KontenStudio
    
    local sudut = Instance.new("UICorner")
    sudut.CornerRadius = UDim.new(0, 4)
    sudut.Parent = tombol
    
    tombol.MouseEnter:Connect(function()
        task.spawn(function()
            TweenService:Create(tombol, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(
                    math.min(warna.R * 255 + 30, 255),
                    math.min(warna.G * 255 + 30, 255),
                    math.min(warna.B * 255 + 30, 255)
                )
            }):Play()
        end)
    end)
    
    tombol.MouseLeave:Connect(function()
        task.spawn(function()
            TweenService:Create(tombol, TweenInfo.new(0.2), {BackgroundColor3 = warna}):Play()
        end)
    end)
    
    return tombol
end

local TombolSimpan = BuatTombolStudio("Simpan", 5, 5, 70, 20, Color3.fromRGB(59, 15, 116))
local TombolMulai = BuatTombolStudio("Mulai", 79, 5, 70, 20, Color3.fromRGB(59, 15, 116))

local TombolLanjut = BuatTombolStudio("LANJUT", 5, 30, 144, 22, Color3.fromRGB(59, 15, 116))

local TombolSebelum = BuatTombolStudio("Sebelum", 5, 57, 70, 20, Color3.fromRGB(59, 15, 116))
local TombolBerikut = BuatTombolStudio("Berikut", 79, 57, 70, 20, Color3.fromRGB(59, 15, 116))

-- ========= GUI KONTROL PUTAR BARU (200x170) =========
local KontrolPutar = Instance.new("Frame")
KontrolPutar.Size = UDim2.fromOffset(200, 170)
KontrolPutar.Position = UDim2.new(0.5, -100, 0.5, -100)
KontrolPutar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
KontrolPutar.BorderSizePixel = 0
KontrolPutar.Active = true
KontrolPutar.Draggable = true
KontrolPutar.Visible = false
KontrolPutar.Parent = ScreenGui

local SudutKontrolPutar = Instance.new("UICorner")
SudutKontrolPutar.CornerRadius = UDim.new(0, 10)
SudutKontrolPutar.Parent = KontrolPutar

local HeaderKontrolPutar = Instance.new("Frame")
HeaderKontrolPutar.Size = UDim2.new(1, 0, 0, 25)
HeaderKontrolPutar.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
HeaderKontrolPutar.BorderSizePixel = 0
HeaderKontrolPutar.Parent = KontrolPutar

local SudutHeaderKontrolPutar = Instance.new("UICorner")
SudutHeaderKontrolPutar.CornerRadius = UDim.new(0, 10)
SudutHeaderKontrolPutar.Parent = HeaderKontrolPutar

local JudulKontrolPutar = Instance.new("TextLabel")
JudulKontrolPutar.Size = UDim2.new(1, -30, 1, 0)
JudulKontrolPutar.BackgroundTransparency = 1
JudulKontrolPutar.Text = ""
JudulKontrolPutar.TextColor3 = Color3.fromRGB(255, 255, 255)
JudulKontrolPutar.Font = Enum.Font.GothamBold
JudulKontrolPutar.TextSize = 10
JudulKontrolPutar.Parent = HeaderKontrolPutar

local TombolTutupKontrolPutar = Instance.new("TextButton")
TombolTutupKontrolPutar.Size = UDim2.fromOffset(20, 20)
TombolTutupKontrolPutar.Position = UDim2.new(1, -22, 0.5, -10)
TombolTutupKontrolPutar.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
TombolTutupKontrolPutar.Text = "×"
TombolTutupKontrolPutar.TextColor3 = Color3.new(1, 1, 1)
TombolTutupKontrolPutar.Font = Enum.Font.GothamBold
TombolTutupKontrolPutar.TextSize = 18
TombolTutupKontrolPutar.Parent = HeaderKontrolPutar

local SudutTutupKontrolPutar = Instance.new("UICorner")
SudutTutupKontrolPutar.CornerRadius = UDim.new(0, 5)
SudutTutupKontrolPutar.Parent = TombolTutupKontrolPutar

local KontenKontrolPutar = Instance.new("Frame")
KontenKontrolPutar.Size = UDim2.new(1, -16, 1, -33)
KontenKontrolPutar.Position = UDim2.new(0, 8, 0, 28)
KontenKontrolPutar.BackgroundTransparency = 1
KontenKontrolPutar.Parent = KontrolPutar

local function BuatTombolKontrolPutar(teks, x, y, w, h, warna)
    local tombol = Instance.new("TextButton")
    tombol.Size = UDim2.fromOffset(w, h)
    tombol.Position = UDim2.fromOffset(x, y)
    tombol.BackgroundColor3 = warna
    tombol.Text = teks
    tombol.TextColor3 = Color3.new(1, 1, 1)
    tombol.Font = Enum.Font.GothamBold
    tombol.TextSize = 13
    tombol.AutoButtonColor = false
    tombol.Parent = KontenKontrolPutar
    
    local sudut = Instance.new("UICorner")
    sudut.CornerRadius = UDim.new(0, 5)
    sudut.Parent = tombol
    
    tombol.MouseEnter:Connect(function()
        task.spawn(function()
            TweenService:Create(tombol, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(
                    math.min(warna.R * 255 + 30, 255),
                    math.min(warna.G * 255 + 30, 255),
                    math.min(warna.B * 255 + 30, 255)
                )
            }):Play()
        end)
    end)
    
    tombol.MouseLeave:Connect(function()
        task.spawn(function()
            TweenService:Create(tombol, TweenInfo.new(0.2), {BackgroundColor3 = warna}):Play()
        end)
    end)
    
    return tombol
end

local function BuatToggleKontrolPutar(teks, x, y, w, h, default)
    local tombol = Instance.new("TextButton")
    tombol.Size = UDim2.fromOffset(w, h)
    tombol.Position = UDim2.fromOffset(x, y)
    tombol.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    tombol.Text = ""
    tombol.Parent = KontenKontrolPutar
    
    local sudut = Instance.new("UICorner")
    sudut.CornerRadius = UDim.new(0, 4)
    sudut.Parent = tombol
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, w - 28, 1, 0)
    label.Position = UDim2.new(0, 4, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = teks
    label.TextColor3 = Color3.fromRGB(200, 200, 220)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = tombol
    
    local toggle = Instance.new("Frame")
    toggle.Size = UDim2.fromOffset(20, 11)
    toggle.Position = UDim2.new(1, -23, 0.5, -5)
    toggle.BackgroundColor3 = default and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
    toggle.BorderSizePixel = 0
    toggle.Parent = tombol
    
    local sudutToggle = Instance.new("UICorner")
    sudutToggle.CornerRadius = UDim.new(1, 0)
    sudutToggle.Parent = toggle
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(7, 7)
    knob.Position = default and UDim2.new(0, 11, 0, 2) or UDim2.new(0, 2, 0, 2)
    knob.BackgroundColor3 = Color3.fromRGB(220, 220, 230)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    
    local sudutKnob = Instance.new("UICorner")
    sudutKnob.CornerRadius = UDim.new(1, 0)
    sudutKnob.Parent = knob
    
    local function Animasi(nyala)
        MainkanSuara("Toggle")
        local infoTween = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local warnaBg = nyala and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
        local posisiKnob = nyala and UDim2.new(0, 11, 0, 2) or UDim2.new(0, 2, 0, 2)
        TweenService:Create(toggle, infoTween, {BackgroundColor3 = warnaBg}):Play()
        TweenService:Create(knob, infoTween, {Position = posisiKnob}):Play()
    end
    
    return tombol, Animasi
end

TombolPutarKontrol = BuatTombolKontrolPutar("MAIN", 5, 5, 190, 32, Color3.fromRGB(59, 15, 116))

TombolLoopKontrol, AnimasiLoopKontrol = BuatToggleKontrolPutar("AutoLoop", 5, 42, 92, 22, false)
TombolShiftLockKontrol, AnimasiShiftLockKontrol = BuatToggleKontrolPutar("ShiftLock", 103, 42, 92, 22, false)

TombolResetKontrol, AnimasiResetKontrol = BuatToggleKontrolPutar("ResetKarakter", 5, 69, 92, 22, false)
TombolRespawnKontrol, AnimasiRespawnKontrol = BuatToggleKontrolPutar("Respawn", 103, 69, 92, 22, false)

TombolLompatKontrol, AnimasiLompatKontrol = BuatToggleKontrolPutar("LompatTakTerbatas", 5, 96, 190, 22, false)

-- ========= GUI UTAMA (250x340) =========
local FrameUtama = Instance.new("Frame")
FrameUtama.Size = UDim2.fromOffset(250, 340)
FrameUtama.Position = UDim2.new(0.5, -125, 0.5, -170)
FrameUtama.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
FrameUtama.BorderSizePixel = 0
FrameUtama.Active = true
FrameUtama.Draggable = true
FrameUtama.Parent = ScreenGui

local SudutUtama = Instance.new("UICorner")
SudutUtama.CornerRadius = UDim.new(0, 12)
SudutUtama.Parent = FrameUtama

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 28)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
Header.BorderSizePixel = 0
Header.Parent = FrameUtama

local SudutHeader = Instance.new("UICorner")
SudutHeader.CornerRadius = UDim.new(0, 12)
SudutHeader.Parent = Header

local Judul = Instance.new("TextLabel")
Judul.Size = UDim2.new(1, 0, 1, 0)
Judul.BackgroundTransparency = 1
Judul.Text = "ByaruL Recorder"
Judul.TextColor3 = Color3.fromRGB(255,255,255)
Judul.Font = Enum.Font.GothamBold
Judul.TextSize = 14
Judul.TextXAlignment = Enum.TextXAlignment.Center
Judul.Parent = Header

local TombolSembunyi = Instance.new("TextButton")
TombolSembunyi.Size = UDim2.fromOffset(22, 22)
TombolSembunyi.Position = UDim2.new(1, -50, 0.5, -11)
TombolSembunyi.BackgroundColor3 = Color3.fromRGB(162, 175, 170)
TombolSembunyi.Text = "_"
TombolSembunyi.TextColor3 = Color3.new(1, 1, 1)
TombolSembunyi.Font = Enum.Font.GothamBold
TombolSembunyi.TextSize = 12
TombolSembunyi.Parent = Header

local SudutSembunyi = Instance.new("UICorner")
SudutSembunyi.CornerRadius = UDim.new(0, 6)
SudutSembunyi.Parent = TombolSembunyi

local TombolTutup = Instance.new("TextButton")
TombolTutup.Size = UDim2.fromOffset(22, 22)
TombolTutup.Position = UDim2.new(1, -25, 0.5, -11)
TombolTutup.BackgroundColor3 = Color3.fromRGB(230, 62, 62)
TombolTutup.Text = "X"
TombolTutup.TextColor3 = Color3.new(1, 1, 1)
TombolTutup.Font = Enum.Font.GothamBold
TombolTutup.TextSize = 10
TombolTutup.Parent = Header

local SudutTutup = Instance.new("UICorner")
SudutTutup.CornerRadius = UDim.new(0, 6)
SudutTutup.Parent = TombolTutup

local Konten = Instance.new("Frame")
Konten.Size = UDim2.new(1, -16, 1, -36)
Konten.Position = UDim2.new(0, 8, 0, 32)
Konten.BackgroundTransparency = 1
Konten.Parent = FrameUtama

local TombolMini = Instance.new("TextButton")
TombolMini.Size = UDim2.fromOffset(40, 40)
TombolMini.Position = UDim2.new(0.5, -20, 0, -30)
TombolMini.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
TombolMini.Text = "A"
TombolMini.TextColor3 = Color3.new(1, 1, 1)
TombolMini.Font = Enum.Font.GothamBold
TombolMini.TextSize = 25
TombolMini.Visible = false
TombolMini.Active = true
TombolMini.Draggable = true
TombolMini.Parent = ScreenGui

local SudutMini = Instance.new("UICorner")
SudutMini.CornerRadius = UDim.new(0, 8)
SudutMini.Parent = TombolMini

local function BuatTombol(teks, x, y, w, h, warna)
    local tombol = Instance.new("TextButton")
    tombol.Size = UDim2.fromOffset(w, h)
    tombol.Position = UDim2.fromOffset(x, y)
    tombol.BackgroundColor3 = warna
    tombol.Text = teks
    tombol.TextColor3 = Color3.new(1, 1, 1)
    tombol.Font = Enum.Font.GothamBold
    tombol.TextSize = 12
    tombol.AutoButtonColor = false
    tombol.Parent = Konten
    
    local sudut = Instance.new("UICorner")
    sudut.CornerRadius = UDim.new(0, 6)
    sudut.Parent = tombol
    
    tombol.MouseEnter:Connect(function()
        TweenService:Create(tombol, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.new(
                math.min(warna.R * 1.2, 1),
                math.min(warna.G * 1.2, 1),
                math.min(warna.B * 1.2, 1)
            )
        }):Play()
    end)
    
    tombol.MouseLeave:Connect(function()
        TweenService:Create(tombol, TweenInfo.new(0.2), {
            BackgroundColor3 = warna
        }):Play()
    end)
    
    return tombol
end

-- Tombol utama
local TombolBukaStudio = BuatTombol("REKAM", 0, 2, 75, 30, Color3.fromRGB(59, 15, 116))
local TombolMenu = BuatTombol("MENU", 79, 2, 75, 30, Color3.fromRGB(59, 15, 116))
local TombolKontrolPutar = BuatTombol("MAIN", 158, 2, 76, 30, Color3.fromRGB(59, 15, 116))

-- Kotak input
local KotakKecepatan = Instance.new("TextBox")
KotakKecepatan.Size = UDim2.fromOffset(60, 22)
KotakKecepatan.Position = UDim2.fromOffset(0, 36)
KotakKecepatan.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
KotakKecepatan.BorderSizePixel = 0
KotakKecepatan.Text = "1.00"
KotakKecepatan.PlaceholderText = "Kecepatan"
KotakKecepatan.TextColor3 = Color3.fromRGB(255, 255, 255)
KotakKecepatan.Font = Enum.Font.GothamBold
KotakKecepatan.TextSize = 8
KotakKecepatan.TextXAlignment = Enum.TextXAlignment.Center
KotakKecepatan.ClearTextOnFocus = false
KotakKecepatan.Parent = Konten

local SudutKecepatan = Instance.new("UICorner")
SudutKecepatan.CornerRadius = UDim.new(0, 4)
SudutKecepatan.Parent = KotakKecepatan

local KotakNamaFile = Instance.new("TextBox")
KotakNamaFile.Size = UDim2.fromOffset(110, 22)
KotakNamaFile.Position = UDim2.fromOffset(62, 36)
KotakNamaFile.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
KotakNamaFile.BorderSizePixel = 0
KotakNamaFile.Text = ""
KotakNamaFile.PlaceholderText = "Nama File Kustom"
KotakNamaFile.TextColor3 = Color3.fromRGB(255, 255, 255)
KotakNamaFile.Font = Enum.Font.GothamBold
KotakNamaFile.TextSize = 8
KotakNamaFile.TextXAlignment = Enum.TextXAlignment.Center
KotakNamaFile.ClearTextOnFocus = false
KotakNamaFile.Parent = Konten

local SudutNamaFile = Instance.new("UICorner")
SudutNamaFile.CornerRadius = UDim.new(0, 4)
SudutNamaFile.Parent = KotakNamaFile

local KotakKecepatanJalan = Instance.new("TextBox")
KotakKecepatanJalan.Size = UDim2.fromOffset(60, 22)
KotakKecepatanJalan.Position = UDim2.fromOffset(174, 36)
KotakKecepatanJalan.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
KotakKecepatanJalan.BorderSizePixel = 0
KotakKecepatanJalan.Text = "16"
KotakKecepatanJalan.PlaceholderText = "Kecepatan Jalan"
KotakKecepatanJalan.TextColor3 = Color3.fromRGB(255, 255, 255)
KotakKecepatanJalan.Font = Enum.Font.GothamBold
KotakKecepatanJalan.TextSize = 8
KotakKecepatanJalan.TextXAlignment = Enum.TextXAlignment.Center
KotakKecepatanJalan.ClearTextOnFocus = false
KotakKecepatanJalan.Parent = Konten

local SudutKecepatanJalan = Instance.new("UICorner")
SudutKecepatanJalan.CornerRadius = UDim.new(0, 4)
SudutKecepatanJalan.Parent = KotakKecepatanJalan

-- Tombol aksi
local TombolSimpanFile = BuatTombol("SIMPAN FILE", 0, 62, 115, 30, Color3.fromRGB(59, 15, 116))
local TombolMuatFile = BuatTombol("MUAT FILE", 119, 62, 115, 30, Color3.fromRGB(59, 15, 116))

local TombolToggleJalur = BuatTombol("TAMPILKAN RUTE", 0, 96, 115, 30, Color3.fromRGB(59, 15, 116))
local TombolGabung = BuatTombol("GABUNG", 119, 96, 115, 30, Color3.fromRGB(59, 15, 116))

-- Daftar rekaman
local DaftarRekaman = Instance.new("ScrollingFrame")
DaftarRekaman.Size = UDim2.new(1, 0, 0, 170)
DaftarRekaman.Position = UDim2.fromOffset(0, 130)
DaftarRekaman.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
DaftarRekaman.BorderSizePixel = 0
DaftarRekaman.ScrollBarThickness = 4
DaftarRekaman.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
DaftarRekaman.ScrollingDirection = Enum.ScrollingDirection.Y
DaftarRekaman.VerticalScrollBarInset = Enum.ScrollBarInset.Always
DaftarRekaman.CanvasSize = UDim2.new(0, 0, 0, 0)
DaftarRekaman.Parent = Konten

local SudutDaftar = Instance.new("UICorner")
SudutDaftar.CornerRadius = UDim.new(0, 6)
SudutDaftar.Parent = DaftarRekaman

-- ========= FUNGSI VALIDASI =========
local function ValidasiKecepatan(teksKecepatan)
    local kecepatan = tonumber(teksKecepatan)
    if not kecepatan then return false, "Angka tidak valid" end
    if kecepatan < 0.25 or kecepatan > 30 then return false, "Kecepatan harus antara 0.25 dan 30" end
    local kecepatanBulat = math.floor((kecepatan * 4) + 0.5) / 4
    return true, kecepatanBulat
end

KotakKecepatan.FocusLost:Connect(function()
    local berhasil, hasil = ValidasiKecepatan(KotakKecepatan.Text)
    if berhasil then
        KecepatanSekarang = hasil
        KotakKecepatan.Text = string.format("%.2f", hasil)
        MainkanSuara("Sukses")
    else
        KotakKecepatan.Text = string.format("%.2f", KecepatanSekarang)
        MainkanSuara("Error")
    end
end)

local function ValidasiKecepatanJalan(teksKecepatanJalan)
    local kecepatanJalan = tonumber(teksKecepatanJalan)
    if not kecepatanJalan then return false, "Angka tidak valid" end
    if kecepatanJalan < 8 or kecepatanJalan > 200 then return false, "Kecepatan jalan harus antara 8 dan 200" end
    return true, kecepatanJalan
end

KotakKecepatanJalan.FocusLost:Connect(function()
    local berhasil, hasil = ValidasiKecepatanJalan(KotakKecepatanJalan.Text)
    if berhasil then
        KecepatanJalanSekarang = hasil
        KotakKecepatanJalan.Text = tostring(hasil)
        local karakter = player.Character
        if karakter and karakter:FindFirstChildOfClass("Humanoid") then
            karakter.Humanoid.WalkSpeed = KecepatanJalanSekarang
        end
        MainkanSuara("Sukses")
    else
        KotakKecepatanJalan.Text = tostring(KecepatanJalanSekarang)
        MainkanSuara("Error")
    end
end)

local function PindahkanRekamanNaik(nama)
    local indexSekarang = table.find(UrutanRekaman, nama)
    if indexSekarang and indexSekarang > 1 then
        UrutanRekaman[indexSekarang] = UrutanRekaman[indexSekarang - 1]
        UrutanRekaman[indexSekarang - 1] = nama
        PerbaruiDaftarRekaman()
    end
end

local function PindahkanRekamanTurun(nama)
    local indexSekarang = table.find(UrutanRekaman, nama)
    if indexSekarang and indexSekarang < #UrutanRekaman then
        UrutanRekaman[indexSekarang] = UrutanRekaman[indexSekarang + 1]
        UrutanRekaman[indexSekarang + 1] = nama
        PerbaruiDaftarRekaman()
    end
end

local function FormatDurasi(detik)
    local menit = math.floor(detik / 60)
    local detikSisa = math.floor(detik % 60)
    return string.format("%d:%02d", menit, detikSisa)
end

function PerbaruiDaftarRekaman()
    for _, child in pairs(DaftarRekaman:GetChildren()) do 
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local posisiY = 0
    for index, nama in ipairs(UrutanRekaman) do
        local rek = RekamanGerakan[nama]
        if not rek then continue end
        
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, -4, 0, 40)
        item.Position = UDim2.new(0, 2, 0, posisiY)
        item.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        item.Parent = DaftarRekaman
    
        local sudut = Instance.new("UICorner")
        sudut.CornerRadius = UDim.new(0, 4)
        sudut.Parent = item
        
        -- Checkbox
        local kotakCentang = Instance.new("TextButton")
        kotakCentang.Size = UDim2.fromOffset(20, 20)
        kotakCentang.Position = UDim2.fromOffset(3, 10)
        kotakCentang.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        kotakCentang.Text = RekamanTercentang[nama] and "✓" or ""
        kotakCentang.TextColor3 = Color3.fromRGB(100, 255, 150)
        kotakCentang.Font = Enum.Font.GothamBold
        kotakCentang.TextSize = 14
        kotakCentang.Parent = item
        
        local sudutCentang = Instance.new("UICorner")
        sudutCentang.CornerRadius = UDim.new(0, 3)
        sudutCentang.Parent = kotakCentang
        
        -- Tombol putar
        local tombolPutar = Instance.new("TextButton")
        tombolPutar.Size = UDim2.fromOffset(30, 20)
        tombolPutar.Position = UDim2.fromOffset(26, 10)
        tombolPutar.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
        tombolPutar.Text = "▶"
        tombolPutar.TextColor3 = Color3.new(1, 1, 1)
        tombolPutar.Font = Enum.Font.GothamBold
        tombolPutar.TextSize = 14
        tombolPutar.Parent = item
        
        local sudutPutar = Instance.new("UICorner")
        sudutPutar.CornerRadius = UDim.new(0, 4)
        sudutPutar.Parent = tombolPutar
        
        -- Tombol hapus
        local tombolHapus = Instance.new("TextButton")
        tombolHapus.Size = UDim2.fromOffset(30, 20)
        tombolHapus.Position = UDim2.fromOffset(59, 10)
        tombolHapus.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
        tombolHapus.Text = "🗑"
        tombolHapus.TextColor3 = Color3.new(1, 1, 1)
        tombolHapus.Font = Enum.Font.GothamBold
        tombolHapus.TextSize = 10
        tombolHapus.Parent = item
        
        local sudutHapus = Instance.new("UICorner")
        sudutHapus.CornerRadius = UDim.new(0, 4)
        sudutHapus.Parent = tombolHapus
        
        -- Nama rekaman
        local kotakNama = Instance.new("TextBox")
        kotakNama.Size = UDim2.new(0, 85, 0, 20)
        kotakNama.Position = UDim2.fromOffset(92, 10)
        kotakNama.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        kotakNama.BorderSizePixel = 0
        kotakNama.Text = namaCheckpoint[nama] or "Checkpoint" .. index
        kotakNama.TextColor3 = Color3.fromRGB(255, 255, 255)
        kotakNama.Font = Enum.Font.GothamBold
        kotakNama.TextSize = 9
        kotakNama.TextXAlignment = Enum.TextXAlignment.Center
        kotakNama.PlaceholderText = "Nama"
        kotakNama.ClearTextOnFocus = false
        kotakNama.Parent = item
        
        local sudutKotakNama = Instance.new("UICorner")
        sudutKotakNama.CornerRadius = UDim.new(0, 3)
        sudutKotakNama.Parent = kotakNama
        
        -- Tombol naik/turun
        local tombolNaik = Instance.new("TextButton")
        tombolNaik.Size = UDim2.fromOffset(30, 20)
        tombolNaik.Position = UDim2.new(1, -60, 0, 10)
        tombolNaik.BackgroundColor3 = index > 1 and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(40, 40, 40)
        tombolNaik.Text = "↑"
        tombolNaik.TextColor3 = Color3.new(1, 1, 1)
        tombolNaik.Font = Enum.Font.GothamBold
        tombolNaik.TextSize = 14
        tombolNaik.Parent = item
        
        local sudutNaik = Instance.new("UICorner")
        sudutNaik.CornerRadius = UDim.new(0, 3)
        sudutNaik.Parent = tombolNaik
        
        local tombolTurun = Instance.new("TextButton")
        tombolTurun.Size = UDim2.fromOffset(30, 20)
        tombolTurun.Position = UDim2.new(1, -28, 0, 10)
        tombolTurun.BackgroundColor3 = index < #UrutanRekaman and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(40, 40, 40)
        tombolTurun.Text = "↓"
        tombolTurun.TextColor3 = Color3.new(1, 1, 1)
        tombolTurun.Font = Enum.Font.GothamBold
        tombolTurun.TextSize = 14
        tombolTurun.Parent = item
        
        local sudutTurun = Instance.new("UICorner")
        sudutTurun.CornerRadius = UDim.new(0, 3)
        sudutTurun.Parent = tombolTurun
        
        -- Info durasi
        local labelInfo = Instance.new("TextLabel")
        labelInfo.Size = UDim2.new(0, 180, 0, 16)
        labelInfo.Position = UDim2.fromOffset(95, 22)
        labelInfo.BackgroundTransparency = 1
        if #rek > 0 then
            local totalDetik = rek[#rek].Timestamp
            labelInfo.Text = FormatDurasi(totalDetik) .. " • " .. #rek .. " frame"
        else
            labelInfo.Text = "0:00 • 0 frame"
        end
        labelInfo.TextColor3 = Color3.fromRGB(200, 200, 220)
        labelInfo.Font = Enum.Font.GothamBold
        labelInfo.TextSize = 8
        labelInfo.TextXAlignment = Enum.TextXAlignment.Left
        labelInfo.Parent = item
        
        -- Event handlers
        kotakNama.FocusLost:Connect(function()
            local namaBaru = kotakNama.Text
            if namaBaru and namaBaru ~= "" then
                namaCheckpoint[nama] = namaBaru
                MainkanSuara("Sukses")
            end
        end)
        
        kotakCentang.MouseButton1Click:Connect(function()
            RekamanTercentang[nama] = not RekamanTercentang[nama]
            kotakCentang.Text = RekamanTercentang[nama] and "✓" or ""
            AnimasiKlikTombol(kotakCentang)
        end)
        
        tombolNaik.MouseButton1Click:Connect(function()
            if index > 1 then 
                AnimasiKlikTombol(tombolNaik)
                PindahkanRekamanNaik(nama) 
            end
        end)
        
        tombolTurun.MouseButton1Click:Connect(function()
            if index < #UrutanRekaman then 
                AnimasiKlikTombol(tombolTurun)
                PindahkanRekamanTurun(nama) 
            end
        end)
        
        tombolPutar.MouseButton1Click:Connect(function()
            if not SedangMain then 
                AnimasiKlikTombol(tombolPutar)
                MainkanRekaman(nama) 
            end
        end)
        
        tombolHapus.MouseButton1Click:Connect(function()
            AnimasiKlikTombol(tombolHapus)
            RekamanGerakan[nama] = nil
            namaCheckpoint[nama] = nil
            RekamanTercentang[nama] = nil
            local idx = table.find(UrutanRekaman, nama)
            if idx then table.remove(UrutanRekaman, idx) end
            PerbaruiDaftarRekaman()
        end)
        
        posisiY = posisiY + 43
    end
    
    DaftarRekaman.CanvasSize = UDim2.new(0, 0, 0, math.max(posisiY, DaftarRekaman.AbsoluteSize.Y))
end

-- ========= SISTEM SIMPAN/MUAT YANG DIPERBAIKI =========
local function SimpanKeJSON()
    local namaFile = KotakNamaFile.Text
    if namaFile == "" then namaFile = "RekamanSaya" end
    namaFile = namaFile .. ".json"
    
    local adaRekamanTercentang = false
    for nama, tercentang in pairs(RekamanTercentang) do
        if tercentang then
            adaRekamanTercentang = true
            break
        end
    end
    
    if not adaRekamanTercentang then
        MainkanSuara("Error")
        return
    end
    
    local berhasil, err = pcall(function()
        local dataSimpan = {
            Versi = "2.1",
            Terobfuscate = true,
            Checkpoint = {},
            UrutanRekaman = {},
            NamaCheckpoint = {}
        }
        
        for _, nama in ipairs(UrutanRekaman) do
            if RekamanTercentang[nama] then
                local frame = RekamanGerakan[nama]
                if frame then
                    local dataCheckpoint = {
                        Nama = nama,
                        NamaTampilan = namaCheckpoint[nama] or "checkpoint",
                        Frame = frame
                    }
                    table.insert(dataSimpan.Checkpoint, dataCheckpoint)
                    table.insert(dataSimpan.UrutanRekaman, nama)
                    dataSimpan.NamaCheckpoint[nama] = namaCheckpoint[nama]
                end
            end
        end
        
        local rekamanUntukObfuscate = {}
        for _, nama in ipairs(dataSimpan.UrutanRekaman) do
            rekamanUntukObfuscate[nama] = RekamanGerakan[nama]
        end
        
        local dataTerobfuscate = ObfuscateDataRekaman(rekamanUntukObfuscate)
        dataSimpan.FrameTerobfuscate = dataTerobfuscate
        
        local stringJSON = HttpService:JSONEncode(dataSimpan)
        
        -- PERBAIKAN: Gunakan writefile dengan aman
        if writefile then
            writefile(namaFile, stringJSON)
            MainkanSuara("Sukses")
        else
            MainkanSuara("Error")
        end
    end)
    
    if not berhasil then
        MainkanSuara("Error")
    end
end

local function MuatDariJSON()
    local namaFile = KotakNamaFile.Text
    if namaFile == "" then namaFile = "RekamanSaya" end
    namaFile = namaFile .. ".json"
    
    local berhasil, err = pcall(function()
        -- PERBAIKAN: Cek apakah file exists dengan aman
        if not isfile or not readfile then
            MainkanSuara("Error")
            return
        end
        
        if not isfile(namaFile) then
            MainkanSuara("Error")
            return
        end
        
        local stringJSON = readfile(namaFile)
        local dataSimpan = HttpService:JSONDecode(stringJSON)
        
        RekamanGerakan = {}
        UrutanRekaman = dataSimpan.UrutanRekaman or {}
        namaCheckpoint = dataSimpan.NamaCheckpoint or {}
        RekamanTercentang = {}
        
        if dataSimpan.Terobfuscate and dataSimpan.FrameTerobfuscate then
            local dataTerdeobfuscate = DeobfuscateDataRekaman(dataSimpan.FrameTerobfuscate)
            
            for _, dataCheckpoint in ipairs(dataSimpan.Checkpoint or {}) do
                local nama = dataCheckpoint.Nama
                local frame = dataTerdeobfuscate[nama]
                
                if frame then
                    RekamanGerakan[nama] = frame
                    if not table.find(UrutanRekaman, nama) then
                        table.insert(UrutanRekaman, nama)
                    end
                end
            end
        else
            for _, dataCheckpoint in ipairs(dataSimpan.Checkpoint or {}) do
                local nama = dataCheckpoint.Nama
                local frame = dataCheckpoint.Frame
                
                if frame then
                    RekamanGerakan[nama] = frame
                    if not table.find(UrutanRekaman, nama) then
                        table.insert(UrutanRekaman, nama)
                    end
                end
            end
        end
        
        PerbaruiDaftarRekaman()
        MainkanSuara("Sukses")
    end)
    
    if not berhasil then
        MainkanSuara("Error")
    end
end

-- ========= VISUALISASI JALUR YANG DIPERBAIKI =========
local function VisualisasiSemuaJalur()
    HapusVisualisasiJalur()
    
    if not TampilkanJalur then return end
    
    for _, nama in ipairs(UrutanRekaman) do
        local rekaman = RekamanGerakan[nama]
        if not rekaman or #rekaman < 2 then continue end
        
        local posisiSebelum = Vector3.new(
            rekaman[1].Posisi[1],
            rekaman[1].Posisi[2], 
            rekaman[1].Posisi[3]
        )
        
        for i = 2, #rekaman, 3 do
            local frame = rekaman[i]
            local posisiSekarang = Vector3.new(frame.Posisi[1], frame.Posisi[2], frame.Posisi[3])
            
            if (posisiSekarang - posisiSebelum).Magnitude > 0.5 then
                BuatSegmenJalur(posisiSebelum, posisiSekarang)
                posisiSebelum = posisiSekarang
            end
        end
    end
end

-- ========= SISTEM PUTAR CERDAS YANG DIPERBAIKI =========
function PutarRekamanCerdas(jarakMaks)
    if SedangMain then return end
    
    local karakter = player.Character
    if not karakter or not karakter:FindFirstChild("HumanoidRootPart") then
        MainkanSuara("Error")
        return
    end

    local posisiSekarang = karakter.HumanoidRootPart.Position
    local rekamanTerbaik = nil
    local frameTerbaik = 1
    local jarakTerbaik = math.huge
    local namaTerbaik = nil
    
    for _, namaRekaman in ipairs(UrutanRekaman) do
        local rekaman = RekamanGerakan[namaRekaman]
        if rekaman and #rekaman > 0 then
            local frameTerdekat, jarakFrame = CariFrameTerdekat(rekaman, posisiSekarang)
            
            if jarakFrame < jarakTerbaik and jarakFrame <= (jarakMaks or 40) then
                jarakTerbaik = jarakFrame
                rekamanTerbaik = rekaman
                frameTerbaik = frameTerdekat
                namaTerbaik = namaRekaman
            end
        end
    end
    
    if rekamanTerbaik then
        PutarDariFrameTertentu(rekamanTerbaik, frameTerbaik, namaTerbaik)
    else
        local rekamanPertama = UrutanRekaman[1] and RekamanGerakan[UrutanRekaman[1]]
        if rekamanPertama then
            PutarDariFrameTertentu(rekamanPertama, 1, UrutanRekaman[1])
        else
            MainkanSuara("Error")
        end
    end
end

function PutarDariFrameTertentu(rekaman, frameAwal, namaRekaman)
    if SedangMain then return end
    
    local karakter = player.Character
    if not karakter or not karakter:FindFirstChild("HumanoidRootPart") then
        MainkanSuara("Error")
        return
    end

    SedangMain = true
    SedangJeda = false
    RekamanYangDimainkan = rekaman
    DijedaDiFrame = 0
    akumulatorPutar = 0
    
    local hrp = karakter:FindFirstChild("HumanoidRootPart")
    local posisiSekarang = hrp.Position
    local frameTarget = rekaman[frameAwal]
    local posTarget = DapatkanPosisiFrame(frameTarget)
    
    local jarak = (posisiSekarang - posTarget).Magnitude
    local waktuTransisi = math.min(DURASI_TRANSISI_HALUS, jarak / 50)
    
    if jarak > 5 then
        local cframeTransisi = CFrame.lookAt(posisiSekarang, posTarget)
        hrp.CFrame = cframeTransisi
        
        local infoTween = TweenInfo.new(waktuTransisi, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(hrp, infoTween, {CFrame = DapatkanCFrameFrame(frameTarget)}):Play()
        task.wait(waktuTransisi)
    end
    
    framePutarSekarang = frameAwal
    waktuMulaiPutar = tick() - (DapatkanTimestampFrame(rekaman[frameAwal]) / KecepatanSekarang)
    totalDurasiJeda = 0
    waktuMulaiJeda = 0
    statePutarTerakhir = nil
    waktuGantiStateTerakhir = 0

    SimpanStateHumanoid()
    MainkanSuara("Main")
    
    TombolPutarKontrol.Text = "BERHENTI"
    TombolPutarKontrol.BackgroundColor3 = Color3.fromRGB(200, 50, 60)

    koneksiPutar = RunService.Heartbeat:Connect(function(deltaTime)
        if not SedangMain then
            koneksiPutar:Disconnect()
            KembalikanKontrolPenuh()
            PerbaruiPenandaJeda()
            statePutarTerakhir = nil
            waktuGantiStateTerakhir = 0
            TombolPutarKontrol.Text = "MAIN"
            TombolPutarKontrol.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
            PerbaruiStatusTombolPutar()
            return
        end
        
        local karakter = player.Character
        if not karakter or not karakter:FindFirstChild("HumanoidRootPart") then
            SedangMain = false
            KembalikanKontrolPenuh()
            PerbaruiPenandaJeda()
            statePutarTerakhir = nil
            waktuGantiStateTerakhir = 0
            TombolPutarKontrol.Text = "MAIN"
            TombolPutarKontrol.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
            PerbaruiStatusTombolPutar()
            return
        end
        
        local hum = karakter:FindFirstChildOfClass("Humanoid")
        local hrp = karakter:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then
            SedangMain = false
            KembalikanKontrolPenuh()
            PerbaruiPenandaJeda()
            statePutarTerakhir = nil
            waktuGantiStateTerakhir = 0
            TombolPutarKontrol.Text = "MAIN"
            TombolPutarKontrol.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
            PerbaruiStatusTombolPutar()
            return
        end

        akumulatorPutar = akumulatorPutar + deltaTime
        
        while akumulatorPutar >= INTERVAL_WAKTU_TETAP do
            akumulatorPutar = akumulatorPutar - INTERVAL_WAKTU_TETAP
            
            local waktuSekarang = tick()
            local waktuEfektif = (waktuSekarang - waktuMulaiPutar - totalDurasiJeda) * KecepatanSekarang
            
            while framePutarSekarang < #rekaman and DapatkanTimestampFrame(rekaman[framePutarSekarang + 1]) <= waktuEfektif do
                framePutarSekarang = framePutarSekarang + 1
            end

            if framePutarSekarang >= #rekaman then
                SedangMain = false
                KembalikanKontrolPenuh()
                MainkanSuara("Sukses")
                PerbaruiPenandaJeda()
                statePutarTerakhir = nil
                waktuGantiStateTerakhir = 0
                TombolPutarKontrol.Text = "MAIN"
                TombolPutarKontrol.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                PerbaruiStatusTombolPutar()
                return
            end

            local frame = rekaman[framePutarSekarang]
            if not frame then
                SedangMain = false
                KembalikanKontrolPenuh()
                PerbaruiPenandaJeda()
                statePutarTerakhir = nil
                waktuGantiStateTerakhir = 0
                TombolPutarKontrol.Text = "MAIN"
                TombolPutarKontrol.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                PerbaruiStatusTombolPutar()
                return
            end

            task.spawn(function()
                hrp.CFrame = DapatkanCFrameFrame(frame)
                hrp.AssemblyLinearVelocity = DapatkanKecepatanFrame(frame)
                
                if hum then
                    hum.WalkSpeed = DapatkanKecepatanJalanFrame(frame) * KecepatanSekarang
                    hum.AutoRotate = false
                    
                    statePutarTerakhir, waktuGantiStateTerakhir = ProsesStateHumanoid(
                        hum, frame, statePutarTerakhir, waktuGantiStateTerakhir
                    )
                end
                
                if ShiftLockAktif then
                    TerapkanShiftLockTerlihat()
                end
            end)
        end
    end)
    
    TambahkanKoneksi(koneksiPutar)
    PerbaruiStatusTombolPutar()
end

function MainkanRekaman(nama)
    if nama then
        local rekaman = RekamanGerakan[nama]
        if rekaman then
            PutarDariFrameTertentu(rekaman, 1, nama)
        end
    else
        PutarRekamanCerdas(40)
    end
end

-- ========= SISTEM AUTO LOOP YANG DIPERBAIKI =========
function MulaiAutoLoopSemua()
    if not AutoLoop then return end
    
    if #UrutanRekaman == 0 then
        AutoLoop = false
        AnimasiLoopKontrol(false)
        MainkanSuara("Error")
        return
    end
    
    MainkanSuara("Main")
    
    IndexLoopSekarang = 1
    SedangAutoLoop = true
    statePutarTerakhir = nil
    waktuGantiStateTerakhir = 0
    
    TombolPutarKontrol.Text = "BERHENTI"
    TombolPutarKontrol.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
    
    koneksiLoop = task.spawn(function()
        while AutoLoop and SedangAutoLoop do
            if not AutoLoop or not SedangAutoLoop then
                break
            end
            
            -- Cari rekaman berikutnya yang valid
            local rekamanUntukDimainkan = nil
            local namaRekamanUntukDimainkan = nil
            local percobaan = 0
            
            while percobaan < #UrutanRekaman do
                namaRekamanUntukDimainkan = UrutanRekaman[IndexLoopSekarang]
                rekamanUntukDimainkan = RekamanGerakan[namaRekamanUntukDimainkan]
                
                if rekamanUntukDimainkan and #rekamanUntukDimainkan > 0 then
                    break
                else
                    -- Skip rekaman kosong dan lanjut ke berikutnya
                    IndexLoopSekarang = IndexLoopSekarang + 1
                    if IndexLoopSekarang > #UrutanRekaman then
                        IndexLoopSekarang = 1
                    end
                    percobaan = percobaan + 1
                end
            end
            
            if not rekamanUntukDimainkan or #rekamanUntukDimainkan == 0 then
                -- Semua rekaman kosong, reset ke #1
                IndexLoopSekarang = 1
                task.wait(1)
                continue
            end
            
            if not ApakahKarakterSiap() then
                if AutoRespawn then
                    ResetKarakter()
                    local berhasil = TungguRespawn()
                    if not berhasil then
                        task.wait(2)
                        continue
                    end
                    task.wait(1.5)
                else
                    local percobaanTunggu = 0
                    local percobaanTungguMaks = 60
                    
                    while not ApakahKarakterSiap() and AutoLoop and SedangAutoLoop do
                        percobaanTunggu = percobaanTunggu + 1
                        
                        if percobaanTunggu >= percobaanTungguMaks then
                            AutoLoop = false
                            SedangAutoLoop = false
                            AnimasiLoopKontrol(false)
                            MainkanSuara("Error")
                            break
                        end
                        
                        task.wait(0.5)
                    end
                    
                    if not AutoLoop or not SedangAutoLoop then break end
                    task.wait(1.0)
                end
            end
            
            if not AutoLoop or not SedangAutoLoop then break end
            
            local pemutaranSelesai = false
            local waktuMulaiPutar = tick()
            local frameSekarang = 1
            local jumlahMatiUlang = 0
            local maksMatiUlang = 999999
            local akumulatorLoop = 0
            
            statePutarTerakhir = nil
            waktuGantiStateTerakhir = 0
            
            SimpanStateHumanoid()
            
            -- Resume cerdas untuk auto loop
            local karakter = player.Character
            if karakter and karakter:FindFirstChild("HumanoidRootPart") then
                local posisiSekarang = karakter.HumanoidRootPart.Position
                local frameTerdekat, jarakFrame = CariFrameTerdekat(rekamanUntukDimainkan, posisiSekarang)
                if jarakFrame <= 40 then
                    frameSekarang = frameTerdekat
                    waktuMulaiPutar = tick() - (DapatkanTimestampFrame(rekamanUntukDimainkan[frameTerdekat]) / KecepatanSekarang)
                end
            end
            
            while AutoLoop and SedangAutoLoop and frameSekarang <= #rekamanUntukDimainkan and jumlahMatiUlang < maksMatiUlang do
                
                if not ApakahKarakterSiap() then
                    jumlahMatiUlang = jumlahMatiUlang + 1
                    
                    if AutoRespawn then
                        ResetKarakter()
                        local berhasil = TungguRespawn()
                        
                        if berhasil then
                            KembalikanKontrolPenuh()
                            task.wait(1.5)
                            
                            -- Tetap lanjut dari rekaman yang sama, tapi dari awal
                            frameSekarang = 1
                            waktuMulaiPutar = tick()
                            statePutarTerakhir = nil
                            waktuGantiStateTerakhir = 0
                            akumulatorLoop = 0
                            
                            SimpanStateHumanoid()
                            continue
                        else
                            task.wait(2)
                            continue
                        end
                    else
                        local tungguRespawnManual = 0
                        local tungguMaksManual = 60
                        
                        while not ApakahKarakterSiap() and AutoLoop and SedangAutoLoop do
                            tungguRespawnManual = tungguRespawnManual + 1
                            
                            if tungguRespawnManual >= tungguMaksManual then
                                AutoLoop = false
                                SedangAutoLoop = false
                                AnimasiLoopKontrol(false)
                                MainkanSuara("Error")
                                break
                            end
                            
                            task.wait(0.5)
                        end
                        
                        if not AutoLoop or not SedangAutoLoop then break end
                        
                        KembalikanKontrolPenuh()
                        task.wait(1.5)
                        
                        frameSekarang = 1
                        waktuMulaiPutar = tick()
                        statePutarTerakhir = nil
                        waktuGantiStateTerakhir = 0
                        akumulatorLoop = 0
                        
                        SimpanStateHumanoid()
                        continue
                    end
                end
                
                local karakter = player.Character
                if not karakter or not karakter:FindFirstChild("HumanoidRootPart") then
                    task.wait(0.5)
                    break
                end
                
                local hum = karakter:FindFirstChildOfClass("Humanoid")
                local hrp = karakter:FindFirstChild("HumanoidRootPart")
                if not hum or not hrp then
                    task.wait(0.5)
                    break
                end
                
                local deltaTime = task.wait()
                akumulatorLoop = akumulatorLoop + deltaTime
                
                while akumulatorLoop >= INTERVAL_WAKTU_TETAP do
                    akumulatorLoop = akumulatorLoop - INTERVAL_WAKTU_TETAP
                    
                    local waktuSekarang = tick()
                    local waktuEfektif = (waktuSekarang - waktuMulaiPutar) * KecepatanSekarang
                    
                    while frameSekarang < #rekamanUntukDimainkan and DapatkanTimestampFrame(rekamanUntukDimainkan[frameSekarang + 1]) <= waktuEfektif do
                        frameSekarang = frameSekarang + 1
                    end
                    
                    if frameSekarang >= #rekamanUntukDimainkan then
                        pemutaranSelesai = true
                        break
                    end
                    
                    local frame = rekamanUntukDimainkan[frameSekarang]
                    if frame then
                        task.spawn(function()
                            hrp.CFrame = DapatkanCFrameFrame(frame)
                            hrp.AssemblyLinearVelocity = DapatkanKecepatanFrame(frame)
                            
                            if hum then
                                hum.WalkSpeed = DapatkanKecepatanJalanFrame(frame) * KecepatanSekarang
                                hum.AutoRotate = false
                                
                                statePutarTerakhir, waktuGantiStateTerakhir = ProsesStateHumanoid(
                                    hum, frame, statePutarTerakhir, waktuGantiStateTerakhir
                                )
                            end
        
                            if ShiftLockAktif then
                                TerapkanShiftLockTerlihat()
                            end
                        end)
                    end
                end
                
                if pemutaranSelesai then
                    break
                end
            end
            
            KembalikanKontrolPenuh()
            statePutarTerakhir = nil
            waktuGantiStateTerakhir = 0
            
            if pemutaranSelesai then
                MainkanSuara("Sukses")
                
                -- PERBAIKAN: Selalu kembali ke urutan #1 setelah selesai semua rekaman
                IndexLoopSekarang = IndexLoopSekarang + 1
                if IndexLoopSekarang > #UrutanRekaman then
                    IndexLoopSekarang = 1
                end
                
                task.wait(0.5)
            else
                if not AutoLoop or not SedangAutoLoop then
                    break
                else
                    -- Jika mati/error, tetap increment ke rekaman berikutnya
                    IndexLoopSekarang = IndexLoopSekarang + 1
                    if IndexLoopSekarang > #UrutanRekaman then
                        IndexLoopSekarang = 1
                    end
                    task.wait(1)
                end
            end
        end
        
        SedangAutoLoop = false
        KembalikanKontrolPenuh()
        statePutarTerakhir = nil
        waktuGantiStateTerakhir = 0
        TombolPutarKontrol.Text = "MAIN"
        TombolPutarKontrol.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
        PerbaruiStatusTombolPutar()
    end)
end

function HentikanAutoLoopSemua()
    AutoLoop = false
    SedangAutoLoop = false
    SedangMain = false
    statePutarTerakhir = nil
    waktuGantiStateTerakhir = 0
    
    if koneksiLoop then
        task.cancel(koneksiLoop)
        koneksiLoop = nil
    end
    
    KembalikanKontrolPenuh()
    
    local karakter = player.Character
    if karakter then ResetKarakterLengkap(karakter) end
    
    MainkanSuara("Berhenti")
    TombolPutarKontrol.Text = "MAIN"
    TombolPutarKontrol.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
    PerbaruiStatusTombolPutar()
end

function HentikanPemutaran()
    if AutoLoop then
        HentikanAutoLoopSemua()
        AnimasiLoopKontrol(false)
    end
    
    if not SedangMain then return end
    SedangMain = false
    statePutarTerakhir = nil
    waktuGantiStateTerakhir = 0
    PosisiJedaTerakhir = nil
    RekamanJedaTerakhir = nil
    KembalikanKontrolPenuh()
    
    local karakter = player.Character
    if karakter then ResetKarakterLengkap(karakter) end
    
    MainkanSuara("Berhenti")
    TombolPutarKontrol.Text = "MAIN"
    TombolPutarKontrol.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
    PerbaruiStatusTombolPutar()
end

-- ========= KONTROL PUTAR YANG DISEDERHANAKAN =========
TombolPutarKontrol.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolPutarKontrol)
    if SedangMain or SedangAutoLoop then
        HentikanPemutaran()
    else
        if AutoLoop then
            MulaiAutoLoopSemua()
        else
            PutarRekamanCerdas(40)
        end
    end
end)

TombolLoopKontrol.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolLoopKontrol)
    AutoLoop = not AutoLoop
    AnimasiLoopKontrol(AutoLoop)
    
    if AutoLoop then
        if not next(RekamanGerakan) then
            AutoLoop = false
            AnimasiLoopKontrol(false)
            return
        end
        
        if SedangMain then
            SedangMain = false
            KembalikanKontrolPenuh()
        end
        
        MulaiAutoLoopSemua()
    else
        HentikanAutoLoopSemua()
    end
end)

TombolShiftLockKontrol.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolShiftLockKontrol)
    ToggleShiftLockTerlihat()
    AnimasiShiftLockKontrol(ShiftLockAktif)
end)

TombolRespawnKontrol.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolRespawnKontrol)
    AutoRespawn = not AutoRespawn
    AnimasiRespawnKontrol(AutoRespawn)
    MainkanSuara("Toggle")
end)

TombolResetKontrol.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolResetKontrol)
    AutoReset = not AutoReset
    AnimasiResetKontrol(AutoReset)
    MainkanSuara("Toggle")
end)

TombolLompatKontrol.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolLompatKontrol)
    ToggleLompatTakTerbatas()
    AnimasiLompatKontrol(LompatTakTerbatas)
    MainkanSuara("Toggle")
end)

TombolTutupKontrolPutar.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolTutupKontrolPutar)
    KontrolPutar.Visible = false
end)

-- ========= KONEKSI TOMBOL UTAMA =========
TombolBukaStudio.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolBukaStudio)
    FrameUtama.Visible = false
    StudioRekaman.Visible = true
    -- PerbaruiUIStudio()
end)

TombolKontrolPutar.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolKontrolPutar)
    KontrolPutar.Visible = not KontrolPutar.Visible
end)

TombolMenu.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolMenu)
    task.spawn(function()
        local berhasil, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/arullwah/Wkwkwkw/refs/heads/main/library.lua", true))()
        end)
        
        if berhasil then
            MainkanSuara("Sukses")
        else
            MainkanSuara("Error")
        end
    end)
end)

TombolSimpanFile.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolSimpanFile)
    SimpanKeJSON()
end)

TombolMuatFile.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolMuatFile)
    MuatDariJSON()
end)

TombolToggleJalur.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolToggleJalur)
    TampilkanJalur = not TampilkanJalur
    if TampilkanJalur then
        TombolToggleJalur.Text = "SEMBUNYIKAN RUTE"
        VisualisasiSemuaJalur()
    else
        TombolToggleJalur.Text = "TAMPILKAN RUTE"
        HapusVisualisasiJalur()
    end
end)

TombolGabung.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolGabung)
    BuatRekamanGabungan()
end)

TombolSembunyi.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolSembunyi)
    FrameUtama.Visible = false
    TombolMini.Visible = true
end)

TombolMini.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolMini)
    FrameUtama.Visible = true
    TombolMini.Visible = false
end)

TombolTutup.MouseButton1Click:Connect(function()
    AnimasiKlikTombol(TombolTutup)
    if StudioSedangRekam then
        -- HentikanRekamanStudio()
    end
    if SedangMain or AutoLoop then
        HentikanPemutaran()
    end
    if ShiftLockAktif then
        NonaktifkanShiftLockTerlihat()
    end
    if LompatTakTerbatas then
        NonaktifkanLompatTakTerbatas()
    end
    BersihkanKoneksi()
    HapusVisualisasiJalur()
    ScreenGui:Destroy()
end)

-- ========= INISIALISASI =========
PerbaruiDaftarRekaman()
PerbaruiStatusTombolPutar()

-- Muat rekaman otomatis jika ada
task.spawn(function()
    task.wait(2)
    local namaFile = "RekamanSaya.json"
    if isfile and readfile and isfile(namaFile) then
        MuatDariJSON()
    end
end)

player.CharacterRemoving:Connect(function()
    if StudioSedangRekam then
        -- HentikanRekamanStudio()
    end
    if SedangMain or AutoLoop then
        HentikanPemutaran()
    end
end)

game:GetService("ScriptContext").DescendantRemoving:Connect(function(descendant)
    if descendant == ScreenGui then
        BersihkanKoneksi()
        HapusVisualisasiJalur()
    end
end)