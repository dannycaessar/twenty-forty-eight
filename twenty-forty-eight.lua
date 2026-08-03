local GRID = 4
local TEXT_PAD = 8
local PAD = 3
local CELL_SIZE = 59

local MINI_CELL = 25
local MINI_PAD = 2
local MINI_FRAME_PAD = 4
local MINI_GRID_X = 30
local MINI_GRID_Y = 20

local PULSE_DURATION = 0.3

local BOARD_COLOR = display.color565(250, 248, 239)
local EMPTY_COLOR = display.color565(205, 193, 180)
local WHITE = display.color565(255, 255, 255)
local RED = display.color565(255, 0, 0)

local tC = {
    [0] = EMPTY_COLOR,
    [2] = display.color565(238, 228, 218),
    [4] = display.color565(237, 224, 200),
    [8] = display.color565(242, 177, 121),
    [16] = display.color565(245, 149, 99),
    [32] = display.color565(246, 124, 95),
    [64] = display.color565(246, 94, 59),
    [128] = display.color565(237, 207, 114),
    [256] = display.color565(237, 204, 97),
    [512] = display.color565(237, 200, 80),
    [1024] = display.color565(237, 197, 63),
    [2048] = display.color565(237, 194, 46),
}
local tCDefault = display.color565(60, 58, 50)

local tileVals = {2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048}
local tileStrs = {"2", "4", "8", "16", "32", "64", "128", "256", "512", "1024", "2048"}
local dStr = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}

local w, h
local gridX, gridY

local board
local score
local gameOver
local won
local mergeCells
local pulseStartTime
local animating
local prevBoard
local moveDir

local currentScreen
local launchedFromGame
local savedMessage
local savedMessageTime
local gameSavedMsg
local gameSavedMsgTime

local function cellX(c)
    return gridX + (c - 1) * CELL_SIZE
end

local function cellY(r)
    return gridY + (r - 1) * CELL_SIZE
end

local function digitCount(n)
    if n < 10 then return 1 end
    if n < 100 then return 2 end
    if n < 1000 then return 3 end
    return 4
end

local function printNum(n)
    local v = math.floor(n)
    if v == 0 then
        display.print("0")
        return
    end
    local digits = {}
    while v > 0 do
        table.insert(digits, v % 10)
        v = math.floor(v / 10)
    end
    for i = #digits, 1, -1 do
        display.print(dStr[digits[i] + 1])
    end
end

local function printTileNum(v)
    for i = 1, #tileVals do
        if tileVals[i] == v then
            display.print(tileStrs[i])
            return
        end
    end
    display.print(tostring(v))
end

local function drawTileText(x, y, value)
    display.set_text_size(1)
    if value <= 4 then
        display.set_text_color(display.color565(119, 110, 101))
    else
        display.set_text_color(WHITE)
    end
    local digits = digitCount(value)
    local textW = digits * 10
    local textH = 8
    local cx = x + math.floor((CELL_SIZE - textW) / 2)
    local cy = y + math.floor((CELL_SIZE - textH) / 2) + 7
    display.set_cursor(cx, cy)
    printTileNum(value)
end

local function drawTile(x, y, value)
    local v = math.floor(value)
    local bg = tC[v] or tCDefault
    display.fill_rect(x + PAD, y + PAD, CELL_SIZE - PAD * 2, CELL_SIZE - PAD * 2, bg)
    drawTileText(x, y, v)
end

local function drawPulseTile(x, y, value, scale)
    local v = math.floor(value)
    local baseSize = CELL_SIZE - PAD * 2
    local centerX = x + PAD + math.floor(baseSize / 2)
    local centerY = y + PAD + math.floor(baseSize / 2)
    local drawSize = math.floor(baseSize * scale)
    local halfSize = math.floor(drawSize / 2)
    local bg = tC[v] or tCDefault
    display.fill_rect(centerX - halfSize, centerY - halfSize, drawSize, drawSize, bg)
    drawTileText(x, y, v)
end

local function drawMiniBoard(boardData)
    local frameColor = display.color565(187, 173, 160)
    local frameX = MINI_GRID_X - MINI_FRAME_PAD
    local frameY = MINI_GRID_Y - MINI_FRAME_PAD
    local frameW = 4 * MINI_CELL + 2 * MINI_FRAME_PAD
    local frameH = 4 * MINI_CELL + 2 * MINI_FRAME_PAD
    display.fill_rect(frameX, frameY, frameW, frameH, frameColor)

    for r = 1, 4 do
        for c = 1, 4 do
            local x = MINI_GRID_X + (c - 1) * MINI_CELL
            local y = MINI_GRID_Y + (r - 1) * MINI_CELL
            local v = boardData[r][c]
            local bg = tC[v] or tCDefault
            display.fill_rect(x + MINI_PAD, y + MINI_PAD, MINI_CELL - MINI_PAD * 2, MINI_CELL - MINI_PAD * 2, bg)
        end
    end
end

local function drawSavedMessageOverlay()
    local msgW = 120
    local msgH = 20
    local msgX = math.floor((w - msgW) / 2)
    local msgY = math.floor((h - msgH) / 2)
    local msgBg = display.color565(119, 110, 101)
    display.fill_rect(msgX, msgY, msgW, msgH, msgBg)
    display.set_text_size(1)
    display.set_text_color(WHITE)
    display.set_cursor(msgX + 10, msgY + 15)
    display.print("Game Saved")
end

local function drawHUD()
    display.set_text_size(1)
    if won then
        display.set_cursor(TEXT_PAD, h - 10)
        display.set_text_color(display.color565(237, 194, 46))
        display.print("You win! A=continue")
    end
    if gameOver then
        display.set_cursor(TEXT_PAD, h - 10)
        display.set_text_color(RED)
        display.print("Game Over! A=new game")
    end
end

local function drawFullBoard()
    display.fill_screen(BOARD_COLOR)

    for r = 1, GRID do
        for c = 1, GRID do
            local value = board[r][c]
            if value ~= 0 then
                drawTile(cellX(c), cellY(r), value)
            else
                display.fill_rect(cellX(c) + PAD, cellY(r) + PAD, CELL_SIZE - PAD * 2, CELL_SIZE - PAD * 2, EMPTY_COLOR)
            end
        end
    end

    drawHUD()
end

local function drawPulseFrame()
    local elapsed = util.time() - pulseStartTime
    local t = elapsed / PULSE_DURATION
    if t > 1 then t = 1 end

    local scale = 1 + 0.12 * (1 - t) * (1 - t)

    for i = 1, #mergeCells do
        local cell = mergeCells[i]
        drawPulseTile(cellX(cell.c), cellY(cell.r), cell.value, scale)
    end
end

local function drawLaunchScreen()
    local darkColor = display.color565(119, 110, 101)

    display.fill_screen(BOARD_COLOR)

    display.set_text_size(1)
    local lineY = 50
    local lineX = 150
    display.set_text_color(darkColor)
    display.set_cursor(lineX, lineY)
    display.print("Best")
    lineY = lineY + 18
    display.set_cursor(lineX, lineY)
    printNum(state.highScore or 0)

    local showScore = false
    local showBoard = false
    local boardToShow = nil
    local displayScore = 0

    if launchedFromGame then
        showScore = true
        showBoard = true
        boardToShow = board
        displayScore = score
    elseif state.hasSavedGame == 1 then
        showScore = true
        showBoard = true
        displayScore = state.savedScore or 0
        boardToShow = {
            {state.br0c0 or 0, state.br0c1 or 0, state.br0c2 or 0, state.br0c3 or 0},
            {state.br1c0 or 0, state.br1c1 or 0, state.br1c2 or 0, state.br1c3 or 0},
            {state.br2c0 or 0, state.br2c1 or 0, state.br2c2 or 0, state.br2c3 or 0},
            {state.br3c0 or 0, state.br3c1 or 0, state.br3c2 or 0, state.br3c3 or 0},
        }
    end

    if showScore then
        lineY = lineY + 18
        display.set_text_color(darkColor)
        display.set_cursor(lineX, lineY)
        display.print("Score")
        lineY = lineY + 18
        display.set_cursor(lineX, lineY)
        printNum(displayScore)
    end

    if showBoard then
        drawMiniBoard(boardToShow)
    end

    local btnY = 150
    local btnX = math.floor((w - 120) / 2)

    display.set_text_size(1)
    display.set_text_color(darkColor)

    if launchedFromGame then
        display.set_cursor(btnX, btnY)
        display.print("A - Continue")
    elseif state.hasSavedGame == 1 then
        display.set_cursor(btnX, btnY)
        display.print("A - Continue")
    else
        display.set_cursor(btnX, btnY)
        display.print("A - Start Game")
    end

    btnY = btnY + 18
    display.set_text_color(darkColor)
    display.set_cursor(btnX, btnY)
    display.print("C - New Game")

    btnY = btnY + 18
    display.set_cursor(btnX, btnY)
    display.print("D - Save Game")
    btnY = btnY + 18

    display.set_text_color(darkColor)
    display.set_cursor(btnX, btnY + 5)
    display.print("Start - Exit")

    if savedMessage then
        drawSavedMessageOverlay()
    end
end

local function addRandomTile()
    local empty = {}
    for r = 1, GRID do
        for c = 1, GRID do
            if board[r][c] == 0 then
                table.insert(empty, {r, c})
            end
        end
    end
    if #empty == 0 then return end
    local idx = math.floor(math.random() * #empty) + 1
    local tile = empty[idx]
    board[tile[1]][tile[2]] = (math.random() < 0.9) and 2 or 4
end

local function canMove()
    for r = 1, GRID do
        for c = 1, GRID do
            if board[r][c] == 0 then return true end
            if c < GRID and board[r][c] == board[r][c + 1] then return true end
            if r < GRID and board[r][c] == board[r + 1][c] then return true end
        end
    end
    return false
end

local function compressRow(row)
    local result = {}
    for i = 1, #row do
        if row[i] ~= 0 then
            table.insert(result, row[i])
        end
    end
    while #result < GRID do
        table.insert(result, 0)
    end
    return result
end

local function mergeRow(row)
    for i = 1, #row - 1 do
        if row[i] ~= 0 and row[i] == row[i + 1] then
            row[i] = row[i] * 2
            score = score + row[i]
            if row[i] == 2048 then
                won = true
            end
            row[i + 1] = 0
        end
    end
    return row
end

local function processRow(row)
    row = compressRow(row)
    row = mergeRow(row)
    row = compressRow(row)
    return row
end

local function copyBoard()
    local copy = {}
    for r = 1, GRID do
        copy[r] = {}
        for c = 1, GRID do
            copy[r][c] = board[r][c]
        end
    end
    return copy
end

local function didBoardChange(oldBoard, newBoard)
    for r = 1, GRID do
        for c = 1, GRID do
            if oldBoard[r][c] ~= newBoard[r][c] then return true end
        end
    end
    return false
end

local function matchLine(oldLine, newLine)
    local oldTiles = {}
    for i = 1, GRID do
        if oldLine[i] ~= 0 then
            table.insert(oldTiles, {val = oldLine[i], pos = i})
        end
    end

    local newTiles = {}
    for i = 1, GRID do
        if newLine[i] ~= 0 then
            table.insert(newTiles, {val = newLine[i], pos = i})
        end
    end

    local result = {}
    local oi = 1
    local ni = 1

    while oi <= #oldTiles and ni <= #newTiles do
        local ot = oldTiles[oi]
        local nt = newTiles[ni]

        if nt.val == ot.val then
            table.insert(result, {from = ot.pos, to = nt.pos, value = nt.val, merged = false, mergeFrom = 0})
            oi = oi + 1
            ni = ni + 1
        elseif oi < #oldTiles and oldTiles[oi + 1].val == ot.val and nt.val == ot.val * 2 then
            table.insert(result, {
                from = ot.pos,
                mergeFrom = oldTiles[oi + 1].pos,
                to = nt.pos,
                value = nt.val,
                merged = true
            })
            oi = oi + 2
            ni = ni + 1
        else
            oi = oi + 1
        end
    end
    return result
end

local function findMergeCells(oldBoard, dir)
    mergeCells = {}

    if dir == 0 then
        for r = 1, GRID do
            local oldRow = {oldBoard[r][1], oldBoard[r][2], oldBoard[r][3], oldBoard[r][4]}
            local newRow = {board[r][1], board[r][2], board[r][3], board[r][4]}
            local matches = matchLine(oldRow, newRow)
            for i = 1, #matches do
                if matches[i].merged then
                    table.insert(mergeCells, {r = r, c = matches[i].to, value = matches[i].value})
                end
            end
        end
    elseif dir == 1 then
        for r = 1, GRID do
            local oldRow = {}
            for c = GRID, 1, -1 do table.insert(oldRow, oldBoard[r][c]) end
            local newRow = {}
            for c = GRID, 1, -1 do table.insert(newRow, board[r][c]) end
            local matches = matchLine(oldRow, newRow)
            for i = 1, #matches do
                if matches[i].merged then
                    table.insert(mergeCells, {r = r, c = GRID - matches[i].to + 1, value = matches[i].value})
                end
            end
        end
    elseif dir == 2 then
        for c = 1, GRID do
            local oldCol = {oldBoard[1][c], oldBoard[2][c], oldBoard[3][c], oldBoard[4][c]}
            local newCol = {board[1][c], board[2][c], board[3][c], board[4][c]}
            local matches = matchLine(oldCol, newCol)
            for i = 1, #matches do
                if matches[i].merged then
                    table.insert(mergeCells, {r = matches[i].to, c = c, value = matches[i].value})
                end
            end
        end
    elseif dir == 3 then
        for c = 1, GRID do
            local oldCol = {}
            for r = GRID, 1, -1 do table.insert(oldCol, oldBoard[r][c]) end
            local newCol = {}
            for r = GRID, 1, -1 do table.insert(newCol, board[r][c]) end
            local matches = matchLine(oldCol, newCol)
            for i = 1, #matches do
                if matches[i].merged then
                    table.insert(mergeCells, {r = GRID - matches[i].to + 1, c = c, value = matches[i].value})
                end
            end
        end
    end
end

local function moveLeft()
    moveDir = 0
    local oldBoard = copyBoard()
    for r = 1, GRID do
        local row = {board[r][1], board[r][2], board[r][3], board[r][4]}
        row = processRow(row)
        board[r][1] = row[1]; board[r][2] = row[2]; board[r][3] = row[3]; board[r][4] = row[4]
    end
    if didBoardChange(oldBoard, board) then
        prevBoard = oldBoard
        return true
    end
    return false
end

local function moveRight()
    moveDir = 1
    local oldBoard = copyBoard()
    for r = 1, GRID do
        local row = {board[r][4], board[r][3], board[r][2], board[r][1]}
        row = processRow(row)
        board[r][1] = row[4]; board[r][2] = row[3]; board[r][3] = row[2]; board[r][4] = row[1]
    end
    if didBoardChange(oldBoard, board) then
        prevBoard = oldBoard
        return true
    end
    return false
end

local function moveUp()
    moveDir = 2
    local oldBoard = copyBoard()
    for c = 1, GRID do
        local row = {board[1][c], board[2][c], board[3][c], board[4][c]}
        row = processRow(row)
        board[1][c] = row[1]; board[2][c] = row[2]; board[3][c] = row[3]; board[4][c] = row[4]
    end
    if didBoardChange(oldBoard, board) then
        prevBoard = oldBoard
        return true
    end
    return false
end

local function moveDown()
    moveDir = 3
    local oldBoard = copyBoard()
    for c = 1, GRID do
        local row = {board[4][c], board[3][c], board[2][c], board[1][c]}
        row = processRow(row)
        board[1][c] = row[4]; board[2][c] = row[3]; board[3][c] = row[2]; board[4][c] = row[1]
    end
    if didBoardChange(oldBoard, board) then
        prevBoard = oldBoard
        return true
    end
    return false
end

local function resetGame()
    for r = 1, GRID do
        for c = 1, GRID do
            board[r][c] = 0
        end
    end
    score = 0
    gameOver = false
    won = false
    mergeCells = {}
    animating = false
    prevBoard = nil
    addRandomTile()
    addRandomTile()
end

local function saveGame()
    state.br0c0 = board[1][1]; state.br0c1 = board[1][2]; state.br0c2 = board[1][3]; state.br0c3 = board[1][4]
    state.br1c0 = board[2][1]; state.br1c1 = board[2][2]; state.br1c2 = board[2][3]; state.br1c3 = board[2][4]
    state.br2c0 = board[3][1]; state.br2c1 = board[3][2]; state.br2c2 = board[3][3]; state.br2c3 = board[3][4]
    state.br3c0 = board[4][1]; state.br3c1 = board[4][2]; state.br3c2 = board[4][3]; state.br3c3 = board[4][4]
    state.savedScore = score
    state.hasSavedGame = 1
    if score > (state.highScore or 0) then
        state.highScore = score
    end
    state.save()
end

local function loadBoardFromState()
    board[1][1] = state.br0c0 or 0; board[1][2] = state.br0c1 or 0; board[1][3] = state.br0c2 or 0; board[1][4] = state.br0c3 or 0
    board[2][1] = state.br1c0 or 0; board[2][2] = state.br1c1 or 0; board[2][3] = state.br1c2 or 0; board[2][4] = state.br1c3 or 0
    board[3][1] = state.br2c0 or 0; board[3][2] = state.br2c1 or 0; board[3][3] = state.br2c2 or 0; board[3][4] = state.br2c3 or 0
    board[4][1] = state.br3c0 or 0; board[4][2] = state.br3c1 or 0; board[4][3] = state.br3c2 or 0; board[4][4] = state.br3c3 or 0
end

local function loadGame()
    loadBoardFromState()
    score = state.savedScore or 0
    gameOver = false
    won = false
    mergeCells = {}
    animating = false
    prevBoard = nil
end

local function clearSavedGame()
    state.br0c0 = 0; state.br0c1 = 0; state.br0c2 = 0; state.br0c3 = 0
    state.br1c0 = 0; state.br1c1 = 0; state.br1c2 = 0; state.br1c3 = 0
    state.br2c0 = 0; state.br2c1 = 0; state.br2c2 = 0; state.br2c3 = 0
    state.br3c0 = 0; state.br3c1 = 0; state.br3c2 = 0; state.br3c3 = 0
    state.savedScore = 0
    state.hasSavedGame = 0
    state.save()
end

function lilka.init()
    w = display.width
    h = display.height
    gridX = math.floor((w - GRID * CELL_SIZE) / 2)
    gridY = 0

    state.highScore = state.highScore or 0

    board = {
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
        {0, 0, 0, 0},
    }
    score = 0
    gameOver = false
    won = false
    mergeCells = {}
    pulseStartTime = 0
    animating = false
    prevBoard = nil
    moveDir = 0

    currentScreen = "launch"
    launchedFromGame = false
    savedMessage = false
    savedMessageTime = 0
    gameSavedMsg = false
    gameSavedMsgTime = 0
end

function lilka.update(delta)
    local ctrl = controller.get_state()

    if ctrl.start.just_pressed then
        state.save()
        util.exit()
    end

    if currentScreen == "launch" then
        if savedMessage then
            if util.time() - savedMessageTime >= 1 then
                savedMessage = false
                currentScreen = "game"
                launchedFromGame = false
            end
        end

        if not savedMessage then
            if ctrl.a.just_pressed then
                if launchedFromGame then
                    currentScreen = "game"
                    launchedFromGame = false
                elseif state.hasSavedGame == 1 then
                    loadGame()
                    currentScreen = "game"
                else
                    resetGame()
                    currentScreen = "game"
                end
            end

            if ctrl.c.just_pressed then
                clearSavedGame()
                resetGame()
                launchedFromGame = false
                currentScreen = "game"
            end

            if ctrl.d.just_pressed and launchedFromGame then
                saveGame()
                savedMessage = true
                savedMessageTime = util.time()
            end
        end
    else
        if gameSavedMsg then
            if util.time() - gameSavedMsgTime >= 1 then
                gameSavedMsg = false
            end
        end

        if ctrl.d.just_pressed then
            saveGame()
            gameSavedMsg = true
            gameSavedMsgTime = util.time()
        end

        if ctrl.a.just_pressed and gameOver then
            resetGame()
        elseif ctrl.a.just_pressed and won then
            won = false
        elseif ctrl.a.just_pressed then
            launchedFromGame = true
            currentScreen = "launch"
        end

        if animating then
            if pulseStartTime == 0 then
                pulseStartTime = util.time()
            end

            if util.time() - pulseStartTime >= PULSE_DURATION then
                animating = false
                mergeCells = {}
                pulseStartTime = 0
                if not canMove() then
                    gameOver = true
                end
            end
        elseif not gameOver then
            local queuedDir = -1
            if ctrl.left.just_pressed then queuedDir = 0 end
            if ctrl.right.just_pressed then queuedDir = 1 end
            if ctrl.up.just_pressed then queuedDir = 2 end
            if ctrl.down.just_pressed then queuedDir = 3 end

            local moved = false
            if queuedDir == 0 then
                moved = moveLeft()
            elseif queuedDir == 1 then
                moved = moveRight()
            elseif queuedDir == 2 then
                moved = moveUp()
            elseif queuedDir == 3 then
                moved = moveDown()
            end

            if moved then
                findMergeCells(prevBoard, moveDir)
                addRandomTile()
                if #mergeCells > 0 then
                    pulseStartTime = 0
                    animating = true
                end
                if score > (state.highScore or 0) then
                    state.highScore = score
                end
            end
        end
    end
end

function lilka.draw()
    if currentScreen == "launch" then
        drawLaunchScreen()
    else
        drawFullBoard()
        if animating then
            drawPulseFrame()
        end
        if gameSavedMsg then
            drawSavedMessageOverlay()
        end
    end
end
