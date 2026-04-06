-- Stockfish 18 Bot — XADREZ! Roblox
local SERVER = "http://192.168.0.62:8081/move"
local RS = game:GetService("ReplicatedStorage")
local LP = game.Players.LocalPlayer
local WHITE_COLOR = Color3.new(0.85098, 0.843137, 0.788235)
local PIECE_MAP = {King="k",Queen="q",Rook="r",Bishop="b",Knight="n",Pawn="p"}

local function isWhite(color)
    return math.abs(color.R - WHITE_COLOR.R) < 0.05
end

local function uciToColRow(uci)
    local files = {a=1,b=2,c=3,d=4,e=5,f=6,g=7,h=8}
    return {files[uci:sub(1,1)], tonumber(uci:sub(2,2))}, {files[uci:sub(3,3)], tonumber(uci:sub(4,4))}
end

local function getFEN(myTurn)
    local pieces = workspace:FindFirstChild("Pieces")
    local board  = workspace:FindFirstChild("Board")
    if not pieces or not board then return nil end
    local grid = {}
    for row=1,8 do grid[row]={} end
    for _, p in ipairs(pieces:GetChildren()) do
        local mesh = p:FindFirstChildWhichIsA("BasePart")
        if mesh then
            for _, cell in ipairs(board:GetChildren()) do
                if math.abs(cell.Position.X-mesh.Position.X)<2 and math.abs(cell.Position.Z-mesh.Position.Z)<2 then
                    local col,row = cell.Name:match("(%d+),(%d+)")
                    col,row = tonumber(col),tonumber(row)
                    if col and row then
                        local n = PIECE_MAP[p.Name] or "p"
                        grid[row][col] = isWhite(mesh.Color) and n:upper() or n
                    end
                    break
                end
            end
        end
    end
    local rows = {}
    for row=8,1,-1 do
        local s,e = "",0
        for col=1,8 do
            local pc = grid[row][col]
            if pc then if e>0 then s=s..e e=0 end s=s..pc else e=e+1 end
        end
        if e>0 then s=s..e end
        table.insert(rows,s)
    end
    return table.concat(rows,"/").." "..(myTurn and "w" or "b").." KQkq - 0 1"
end

local function isMyTurn()
    for _, gui in ipairs(LP.PlayerGui:GetDescendants()) do
        if gui:IsA("TextLabel") then
            local t = gui.Text
            if (t:find("vez") or t:find("Turno")) and t:find(LP.Name) then return true end
        end
    end
    return false
end

local function getMyColor()
    local pieces = workspace:FindFirstChild("Pieces")
    local board  = workspace:FindFirstChild("Board")
    if pieces and board then
        for _, p in ipairs(pieces:GetChildren()) do
            if p.Name == "King" then
                local mesh = p:FindFirstChildWhichIsA("BasePart")
                if mesh and isWhite(mesh.Color) then
                    for _, cell in ipairs(board:GetChildren()) do
                        if math.abs(cell.Position.X-mesh.Position.X)<2 and math.abs(cell.Position.Z-mesh.Position.Z)<2 then
                            local _,row = cell.Name:match("(%d+),(%d+)")
                            return tonumber(row)<=2 and "white" or "black"
                        end
                    end
                end
            end
        end
    end
    return "white"
end

local function getStockfishMove(fen)
    local ok, res = pcall(function()
        return http.request({Url=SERVER,Method="POST",Headers={["Content-Type"]="application/json"},Body='{"fen":"'..fen..'"}'})
    end)
    if not ok or not res or res.StatusCode~=200 then return nil end
    return res.Body:match('"move"%s*:%s*"([^"]+)"')
end

local function executeMove(uci)
    local from, to = uciToColRow(uci)
    RS.Connections.MovePiece:FireServer({from[1],from[2]},{to[1],to[2]})
    print("[SF18] Jogada:", uci)
end

-- ===== GUI =====
local sg = Instance.new("ScreenGui")
sg.ResetOnSpawn = false
sg.Parent = LP.PlayerGui

local f = Instance.new("Frame")
f.Size = UDim2.new(0, 260, 0, 230)
f.Position = UDim2.new(0, 20, 0, 20)
f.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
f.Active = true
f.Draggable = true
f.Parent = sg

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Stockfish 18 - 4000 ELO"
title.TextColor3 = Color3.fromRGB(255, 200, 0)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.ZIndex = 2
title.Parent = f

local statusL = Instance.new("TextLabel")
statusL.Size = UDim2.new(1, 0, 0, 28)
statusL.Position = UDim2.new(0, 0, 0, 38)
statusL.BackgroundTransparency = 1
statusL.Text = "Pronto!"
statusL.TextColor3 = Color3.fromRGB(180,180,180)
statusL.TextScaled = true
statusL.Font = Enum.Font.Gotham
statusL.ZIndex = 2
statusL.Parent = f

local bestBtn = Instance.new("ImageButton")
bestBtn.Size = UDim2.new(1,-10,0,60)
bestBtn.Position = UDim2.new(0,5,0,72)
bestBtn.BackgroundColor3 = Color3.fromRGB(0,160,80)
bestBtn.Image = ""
bestBtn.ZIndex = 2
bestBtn.Parent = f
local bestL = Instance.new("TextLabel")
bestL.Size = UDim2.new(1,0,1,0)
bestL.BackgroundTransparency = 1
bestL.Text = "BEST MOVE"
bestL.TextColor3 = Color3.white
bestL.TextScaled = true
bestL.Font = Enum.Font.GothamBold
bestL.ZIndex = 10
bestL.Parent = bestBtn

local autoOn = false
local autoBtn = Instance.new("ImageButton")
autoBtn.Size = UDim2.new(1,-10,0,60)
autoBtn.Position = UDim2.new(0,5,0,145)
autoBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)
autoBtn.Image = ""
autoBtn.ZIndex = 2
autoBtn.Parent = f
local autoL = Instance.new("TextLabel")
autoL.Size = UDim2.new(1,0,1,0)
autoL.BackgroundTransparency = 1
autoL.Text = "AUTO: OFF"
autoL.TextColor3 = Color3.white
autoL.TextScaled = true
autoL.Font = Enum.Font.GothamBold
autoL.ZIndex = 10
autoL.Parent = autoBtn

local function doBestMove()
    statusL.Text = "Calculando..."
    if not isMyTurn() then statusL.Text = "Nao e seu turno" return end
    local myColor = getMyColor()
    local fen = getFEN(myColor == "white")
    if not fen then statusL.Text = "Erro: tabuleiro" return end
    print("[SF18] FEN:", fen)
    local move = getStockfishMove(fen)
    if not move then statusL.Text = "Erro: servidor" return end
    executeMove(move)
    statusL.Text = "Jogada: "..move
end

bestBtn.MouseButton1Click:Connect(function() pcall(doBestMove) end)

autoBtn.MouseButton1Click:Connect(function()
    autoOn = not autoOn
    if autoOn then
        autoBtn.BackgroundColor3 = Color3.fromRGB(200,100,0)
        autoL.Text = "AUTO: ON"
    else
        autoBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)
        autoL.Text = "AUTO: OFF"
    end
end)

task.spawn(function()
    while true do
        task.wait(1.5)
        if autoOn and isMyTurn() then
            pcall(doBestMove)
            task.wait(1)
        end
    end
end)

print("[SF18] Bot carregado!")
