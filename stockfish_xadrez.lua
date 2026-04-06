-- Stockfish 18 Bot — XADREZ! Roblox
-- Servidor: python server_stockfish.py (porta 8081)
-- Executor: Xeno

local SERVER = "http://192.168.0.62:8081/move"

local RS = game:GetService("ReplicatedStorage")
local LP = game.Players.LocalPlayer

-- Cores das peças
local WHITE_COLOR = Color3.new(0.85098, 0.843137, 0.788235)
local BLACK_COLOR = Color3.new(0.25098, 0.266667, 0.301961)

-- Mapeamento de peças para FEN
local PIECE_MAP = {
    King   = "k",
    Queen  = "q",
    Rook   = "r",
    Bishop = "b",
    Knight = "n",
    Pawn   = "p",
}

-- Detecta se a cor é branca
local function isWhite(color)
    return math.abs(color.R - WHITE_COLOR.R) < 0.05
end

-- Converte col,row para casa do tabuleiro (ex: col=1,row=1 = a1)
-- No jogo: col 1-8 = a-h, row 1 = rank 1 (brancas), row 8 = rank 8 (pretas)
local function toSquare(col, row)
    local files = {"a","b","c","d","e","f","g","h"}
    return files[col] .. tostring(row)
end

-- Converte UCI (ex: e2e4) para {col,row} origem e destino
local function uciToColRow(uci)
    local files = {a=1,b=2,c=3,d=4,e=5,f=6,g=7,h=8}
    local fc = uci:sub(1,1)
    local fr = tonumber(uci:sub(2,2))
    local tc = uci:sub(3,3)
    local tr = tonumber(uci:sub(4,4))
    return {files[fc], fr}, {files[tc], tr}
end

-- Constrói o FEN lendo posições das peças no workspace
local function getFEN(myTurn)
    local pieces = workspace:FindFirstChild("Pieces")
    local board  = workspace:FindFirstChild("Board")
    if not pieces or not board then return nil end

    -- Monta grid 8x8 vazio
    local grid = {}
    for row = 1, 8 do
        grid[row] = {}
        for col = 1, 8 do
            grid[row][col] = nil
        end
    end

    -- Mapeia cada peça para sua casa
    for _, p in ipairs(pieces:GetChildren()) do
        local mesh = p:FindFirstChildWhichIsA("BasePart")
        if mesh then
            local px, pz = mesh.Position.X, mesh.Position.Z
            for _, cell in ipairs(board:GetChildren()) do
                if math.abs(cell.Position.X - px) < 2 and math.abs(cell.Position.Z - pz) < 2 then
                    -- cell.Name = "col,row"
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

    -- Gera string FEN do grid (row 8 = rank 8 no topo)
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
        if empty > 0 then
            rowStr = rowStr .. tostring(empty)
        end
        table.insert(fenRows, rowStr)
    end

    local turn = myTurn and "w" or "b"
    return table.concat(fenRows, "/") .. " " .. turn .. " KQkq - 0 1"
end

-- Detecta de quem é o turno lendo o título da tela
local function isMyTurn()
    -- Procura pelo label de turno na GUI
    local pg = LP.PlayerGui
    for _, gui in ipairs(pg:GetDescendants()) do
        if gui:IsA("TextLabel") and gui.Text:find(LP.Name) and gui.Text:lower():find("vez") then
            return true
        end
    end
    -- Fallback: verifica o título "A vez de X" ou "Turno de X"
    for _, gui in ipairs(pg:GetDescendants()) do
        if gui:IsA("TextLabel") then
            local t = gui.Text
            if (t:find("vez") or t:find("Turno") or t:find("turn")) and t:find(LP.Name) then
                return true
            end
        end
    end
    return false
end

-- Descobre a cor do jogador (brancas = row 1 e 2, pretas = row 7 e 8)
local function getMyColor()
    -- Procura na linha da partida o nome do jogador
    -- Baseado no print anterior: "sunfish JohnCalculated JohnCalculated 2 2 BasicWhite BasicBlack true"
    -- Primeiro nome = brancas
    local RS2 = game:GetService("ReplicatedStorage")
    local conn = RS2:FindFirstChild("Connections")
    -- Tenta detectar pela posição do Rei
    local pieces = workspace:FindFirstChild("Pieces")
    local board  = workspace:FindFirstChild("Board")
    if pieces and board then
        for _, p in ipairs(pieces:GetChildren()) do
            if p.Name == "King" then
                local mesh = p:FindFirstChildWhichIsA("BasePart")
                if mesh and isWhite(mesh.Color) then
                    -- Rei branco: se está em row 1, você é brancas
                    for _, cell in ipairs(board:GetChildren()) do
                        if math.abs(cell.Position.X - mesh.Position.X) < 2 and
                           math.abs(cell.Position.Z - mesh.Position.Z) < 2 then
                            local _, row = cell.Name:match("(%d+),(%d+)")
                            row = tonumber(row)
                            if row and row <= 2 then
                                return "white"
                            else
                                return "black"
                            end
                        end
                    end
                end
            end
        end
    end
    return "white" -- fallback
end

-- Envia movimento para o servidor Stockfish
local function getStockfishMove(fen)
    local ok, res = pcall(function()
        return http.request({
            Url    = SERVER,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body   = '{"fen":"' .. fen .. '"}',
        })
    end)
    if not ok or not res or res.StatusCode ~= 200 then
        return nil
    end
    local move = res.Body:match('"move"%s*:%s*"([^"]+)"')
    return move
end

-- Executa o movimento no jogo
local function executeMove(uci)
    local mp = RS.Connections.MovePiece
    local from, to = uciToColRow(uci)
    mp:FireServer({from[1], from[2]}, {to[1], to[2]})
    print("[SF18] Jogada executada:", uci)
end

-- ===== GUI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SF18Bot"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LP.PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 260, 0, 210)
frame.Position = UDim2.new(0, 20, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -35, 0, 36)
title.Position = UDim2.new(0, 5, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Stockfish 18 - 4000 ELO"
title.TextColor3 = Color3.fromRGB(255, 200, 0)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -32, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.white
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextScaled = true
closeBtn.BorderSizePixel = 0
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
closeBtn.Parent = frame
closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

local sep = Instance.new("Frame")
sep.Size = UDim2.new(1, -10, 0, 1)
sep.Position = UDim2.new(0, 5, 0, 38)
sep.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
sep.BorderSizePixel = 0
sep.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -10, 0, 28)
status.Position = UDim2.new(0, 5, 0, 42)
status.BackgroundTransparency = 1
status.Text = "Status: Pronto!"
status.TextColor3 = Color3.fromRGB(180, 180, 180)
status.TextScaled = true
status.Font = Enum.Font.Gotham
status.Parent = frame

local bestBtn = Instance.new("TextButton")
bestBtn.Size = UDim2.new(1, -10, 0, 55)
bestBtn.Position = UDim2.new(0, 5, 0, 74)
bestBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
bestBtn.Text = "BEST MOVE"
bestBtn.TextColor3 = Color3.white
bestBtn.Font = Enum.Font.GothamBold
bestBtn.TextScaled = true
bestBtn.BorderSizePixel = 0
Instance.new("UICorner", bestBtn).CornerRadius = UDim.new(0, 6)
bestBtn.Parent = frame

local autoOn = false
local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(1, -10, 0, 55)
autoBtn.Position = UDim2.new(0, 5, 0, 138)
autoBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
autoBtn.Text = "AUTO: OFF"
autoBtn.TextColor3 = Color3.white
autoBtn.Font = Enum.Font.GothamBold
autoBtn.TextScaled = true
autoBtn.BorderSizePixel = 0
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 6)
autoBtn.Parent = frame

-- Função principal: pega e executa melhor jogada
local function doBestMove()
    status.Text = "Status: Calculando..."
    local myColor = getMyColor()
    local myTurn  = (myColor == "white")

    -- Verifica se é meu turno pelo título
    if not isMyTurn() then
        status.Text = "Status: Não é seu turno"
        return
    end

    local fen = getFEN(myTurn)
    if not fen then
        status.Text = "Status: Erro ao ler tabuleiro"
        return
    end

    print("[SF18] FEN:", fen)
    local move = getStockfishMove(fen)
    if not move then
        status.Text = "Status: Erro no servidor"
        return
    end

    executeMove(move)
    status.Text = "Jogada: " .. move
end

-- Botão Best Move
bestBtn.MouseButton1Click:Connect(function()
    pcall(doBestMove)
end)

-- Toggle Automático
autoBtn.MouseButton1Click:Connect(function()
    autoOn = not autoOn
    if autoOn then
        autoBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
        autoBtn.Text = "AUTO: ON"
    else
        autoBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        autoBtn.Text = "AUTO: OFF"
    end
end)

-- Loop automático
task.spawn(function()
    while true do
        task.wait(1.5)
        if autoOn then
            if isMyTurn() then
                pcall(doBestMove)
                task.wait(1)
            end
        end
    end
end)

print("[SF18] Bot carregado! Servidor: " .. SERVER)
status.Text = "Status: Pronto!"
