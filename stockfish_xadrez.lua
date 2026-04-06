-- Stockfish 18 Bot — XADREZ! Roblox
-- Servidor: python server_stockfish.py (porta 8081)

local SERVER = "http://192.168.0.62:8081/move"

local RS = game:GetService("ReplicatedStorage")
local LP = game.Players.LocalPlayer

local WHITE_COLOR = Color3.new(0.85098, 0.843137, 0.788235)

local PIECE_MAP = {
    King   = "k",
    Queen  = "q",
    Rook   = "r",
    Bishop = "b",
    Knight = "n",
    Pawn   = "p",
}

local function isWhite(color)
    return math.abs(color.R - WHITE_COLOR.R) < 0.05
end

local function uciToColRow(uci)
    local files = {a=1,b=2,c=3,d=4,e=5,f=6,g=7,h=8}
    local fc = uci:sub(1,1)
    local fr = tonumber(uci:sub(2,2))
    local tc = uci:sub(3,3)
    local tr = tonumber(uci:sub(4,4))
    return {files[fc], fr}, {files[tc], tr}
end

local function getFEN(myTurn)
    local pieces = workspace:FindFirstChild("Pieces")
    local board  = workspace:FindFirstChild("Board")
    if not pieces or not board then return nil end

    local grid = {}
    for row = 1, 8 do
        grid[row] = {}
        for col = 1, 8 do
            grid[row][col] = nil
        end
    end

    for _, p in ipairs(pieces:GetChildren()) do
        local mesh = p:FindFirstChildWhichIsA("BasePart")
        if mesh then
            local px, pz = mesh.Position.X, mesh.Position.Z
            for _, cell in ipairs(board:GetChildren()) do
                if math.abs(cell.Position.X - px) < 2 and math.abs(cell.Position.Z - pz) < 2 then
                    local col, row = cell.Name:match("(%d+),(%d+)")
                    col = tonumber(col)
                    row = tonumber(row)
                    if col and row then
                        local pieceName = PIECE_MAP[p.Name] or "p"
                        local white = isWhite(mesh.Color)
                        grid[row][col] = white and pieceName:upper() or pieceName
                    end
                    break
                end
            end
        end
    end

    local fenRows = {}
    for row = 8, 1, -1 do
        local rowStr = ""
        local empty = 0
        for col = 1, 8 do
            local piece = grid[row][col]
            if piece then
                if empty > 0 then
                    rowStr = rowStr .. tostring(empty)
                    empty = 0
                end
                rowStr = rowStr .. piece
            else
                empty = empty + 1
            end
        end
        if empty > 0 then rowStr = rowStr .. tostring(empty) end
        table.insert(fenRows, rowStr)
    end

    local turn = myTurn and "w" or "b"
    return table.concat(fenRows, "/") .. " " .. turn .. " KQkq - 0 1"
end

local function isMyTurn()
    for _, gui in ipairs(LP.PlayerGui:GetDescendants()) do
        if gui:IsA("TextLabel") then
            local t = gui.Text
            if (t:find("vez") or t:find("Turno") or t:find("turn")) and t:find(LP.Name) then
                return true
            end
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
                        if math.abs(cell.Position.X - mesh.Position.X) < 2 and
                           math.abs(cell.Position.Z - mesh.Position.Z) < 2 then
                            local _, row = cell.Name:match("(%d+),(%d+)")
                            row = tonumber(row)
                            if row and row <= 2 then return "white" else return "black" end
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
        return http.request({
            Url    = SERVER,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body   = '{"fen":"' .. fen .. '"}',
        })
    end)
    if not ok or not res or res.StatusCode ~= 200 then return nil end
    return res.Body:match('"move"%s*:%s*"([^"]+)"')
end

local function executeMove(uci)
    local mp = RS.Connections.MovePiece
    local from, to = uciToColRow(uci)
    mp:FireServer({from[1], from[2]}, {to[1], to[2]})
    print("[SF18] Jogada:", uci)
end

-- ===== GUI =====
local sg = Instance.new("ScreenGui")
sg.ResetOnSpawn = false
sg.Parent = LP.PlayerGui

local f = Instance.new("Frame")
f.Size = UDim2.new(0, 260, 0, 220)
f.Position = UDim2.new(0, 20, 0, 20)
f.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
f.Active = true
f.Draggable = true
f.Parent = sg
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

-- Título
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -35, 0, 36)
title.Position = UDim2.new(0, 5, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Stockfish 18 - 4000 ELO"
title.TextColor3 = Color3.fromRGB(255, 200, 0)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.ZIndex = 2
title.Parent = f

-- Botão fechar
local closeBtn = Instance.new("ImageButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -32, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
closeBtn.Image = ""
closeBtn.ZIndex = 3
closeBtn.Parent = f
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
local closeL = Instance.new("TextLabel")
closeL.Size = UDim2.new(1,0,1,0)
closeL.BackgroundTransparency = 1
closeL.Text = "X"
closeL.TextColor3 = Color3.white
closeL.TextScaled = true
closeL.Font = Enum.Font.GothamBold
closeL.ZIndex = 4
closeL.Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

-- Status
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -10, 0, 28)
status.Position = UDim2.new(0, 5, 0, 40)
status.BackgroundTransparency = 1
status.Text = "Status: Pronto!"
status.TextColor3 = Color3.fromRGB(180, 180, 180)
status.TextScaled = true
status.Font = Enum.Font.Gotham
status.ZIndex = 2
status.Parent = f

-- Botão Best Move
local bestBtn = Instance.new("ImageButton")
bestBtn.Size = UDim2.new(1, -10, 0, 65)
bestBtn.Position = UDim2.new(0, 5, 0, 75)
bestBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
bestBtn.Image = ""
bestBtn.ZIndex = 3
bestBtn.Parent = f
Instance.new("UICorner", bestBtn).CornerRadius = UDim.new(0, 6)
local bestL = Instance.new("TextLabel")
bestL.Size = UDim2.new(1,0,1,0)
bestL.BackgroundTransparency = 1
bestL.Text = "BEST MOVE"
bestL.TextColor3 = Color3.white
bestL.TextScaled = true
bestL.Font = Enum.Font.GothamBold
bestL.ZIndex = 4
bestL.Parent = bestBtn

-- Botão Auto
local autoOn = false
local autoBtn = Instance.new("ImageButton")
autoBtn.Size = UDim2.new(1, -10, 0, 65)
autoBtn.Position = UDim2.new(0, 5, 0, 148)
autoBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
autoBtn.Image = ""
autoBtn.ZIndex = 3
autoBtn.Parent = f
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 6)
local autoL = Instance.new("TextLabel")
autoL.Size = UDim2.new(1,0,1,0)
autoL.BackgroundTransparency = 1
autoL.Text = "AUTO: OFF"
autoL.TextColor3 = Color3.white
autoL.TextScaled = true
autoL.Font = Enum.Font.GothamBold
autoL.ZIndex = 4
autoL.Parent = autoBtn

-- Lógica
local function doBestMove()
    status.Text = "Calculando..."
    local myColor = getMyColor()
    local myTurn = (myColor == "white")
    if not isMyTurn() then
        status.Text = "Nao e seu turno"
        return
    end
    local fen = getFEN(myTurn)
    if not fen then status.Text = "Erro: tabuleiro" return end
    print("[SF18] FEN:", fen)
    local move = getStockfishMove(fen)
    if not move then status.Text = "Erro: servidor" return end
    executeMove(move)
    status.Text = "Jogada: " .. move
end

bestBtn.MouseButton1Click:Connect(function() pcall(doBestMove) end)

autoBtn.MouseButton1Click:Connect(function()
    autoOn = not autoOn
    if autoOn then
        autoBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
        autoL.Text = "AUTO: ON"
    else
        autoBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
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
