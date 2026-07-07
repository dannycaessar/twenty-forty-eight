// twenty-forty-eight.js — Classic 2048 tile puzzle
// D-pad to move tiles. A to restart. Start to exit.

let w = display.width;
let h = display.height;

let grid = 4;
let statusBar = 16;
let margin = 10;
let textPad = 8;
let pad = 3;
let availW = w - margin;
let availH = h - statusBar - 25;
let cellSize = availW;
if (availH < availW) cellSize = availH;
cellSize = math.floor(cellSize / grid);
if (cellSize < 20) cellSize = 20;
let gridX = math.floor((w - grid * cellSize) / 2);
let gridY = statusBar + 18;

let board = [
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0]
];

let score = 0;
let gameOver = false;
let won = false;

let DEBUG_FPS = true;
let PULSE_DURATION = 0.5;
let mergeCells = [];
let pulseStartTime = 0;
let animating = false;
let prevBoard = null;
let moveDir = 0;
let fpsTime = util.time();
let fpsCount = 0;
let fpsValue = 0;

if (state.highScore === undefined) {
    state.highScore = 0;
}

let tileVals = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048];
let tileStrs = ["2", "4", "8", "16", "32", "64", "128", "256", "512", "1024", "2048"];

let dStr = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"];

function printNum(n) {
    let v = math.floor(n);
    if (v === 0) {
        display.print("0");
        return;
    }
    let digits = [];
    while (v > 0) {
        let rem = v - math.floor(v / 10) * 10;
        digits.push(rem);
        v = math.floor(v / 10);
    }
    for (let i = digits.length - 1; i >= 0; i = i - 1) {
        display.print(dStr[digits[i]]);
    }
}

function printTileNum(v) {
    for (let i = 0; i < tileVals.length; i = i + 1) {
        if (tileVals[i] === v) {
            display.print(tileStrs[i]);
            return;
        }
    }
    display.print(v);
}

function trackFPS() {
    if (!DEBUG_FPS) return;
    fpsCount = fpsCount + 1;
    let now = util.time();
    if (now - fpsTime >= 1) {
        fpsValue = fpsCount;
        fpsCount = 0;
        fpsTime = now;
    }
}

function drawFPS() {
    if (!DEBUG_FPS) return;
    display.fill_rect(w - 60, 2, 58, 8, display.color565(250, 248, 239));
    display.set_text_size(0);
    display.set_text_color(display.color565(3, 178, 90));
    display.set_cursor(w - 58, 2);
    display.print("FPS: ");
    printNum(fpsValue);
}

function digitCount(n) {
    if (n < 10) return 1;
    if (n < 100) return 2;
    if (n < 1000) return 3;
    return 4;
}

function tileColor(value) {
    if (value === 0) return display.color565(205, 193, 180);
    if (value === 2) return display.color565(238, 228, 218);
    if (value === 4) return display.color565(237, 224, 200);
    if (value === 8) return display.color565(242, 177, 121);
    if (value === 16) return display.color565(245, 149, 99);
    if (value === 32) return display.color565(246, 124, 95);
    if (value === 64) return display.color565(246, 94, 59);
    if (value === 128) return display.color565(237, 207, 114);
    if (value === 256) return display.color565(237, 204, 97);
    if (value === 512) return display.color565(237, 200, 80);
    if (value === 1024) return display.color565(237, 197, 63);
    if (value === 2048) return display.color565(237, 194, 46);
    return display.color565(60, 58, 50);
}

function cellX(c) {
    return gridX + c * cellSize;
}

function cellY(r) {
    return gridY + r * cellSize;
}

function addRandomTile() {
    let empty = [];
    for (let r = 0; r < grid; r++) {
        for (let c = 0; c < grid; c++) {
            if (board[r][c] === 0) {
                empty.push([r, c]);
            }
        }
    }
    if (empty.length === 0) return;
    let idx = math.floor(math.random() * empty.length);
    let tile = empty[idx];
    board[tile[0]][tile[1]] = math.random() < 0.9 ? 2 : 4;
}

function canMove() {
    for (let r = 0; r < grid; r++) {
        for (let c = 0; c < grid; c++) {
            if (board[r][c] === 0) return true;
            if (c < grid - 1 && board[r][c] === board[r][c + 1]) return true;
            if (r < grid - 1 && board[r][c] === board[r + 1][c]) return true;
        }
    }
    return false;
}

function compressRow(row) {
    let result = [];
    for (let i = 0; i < row.length; i++) {
        if (row[i] !== 0) {
            result.push(row[i]);
        }
    }
    while (result.length < grid) {
        result.push(0);
    }
    return result;
}

function mergeRow(row) {
    for (let i = 0; i < row.length - 1; i++) {
        if (row[i] !== 0 && row[i] === row[i + 1]) {
            row[i] = row[i] * 2;
            score = score + row[i];
            if (row[i] === 2048) {
                won = true;
            }
            row[i + 1] = 0;
        }
    }
    return row;
}

function processRow(row) {
    row = compressRow(row);
    row = mergeRow(row);
    row = compressRow(row);
    return row;
}

function didBoardChange(oldBoard, newBoard) {
    for (let r = 0; r < grid; r++) {
        for (let c = 0; c < grid; c++) {
            if (oldBoard[r][c] !== newBoard[r][c]) return true;
        }
    }
    return false;
}

function copyBoard() {
    let copy = [];
    for (let r = 0; r < grid; r++) {
        copy[r] = [];
        for (let c = 0; c < grid; c++) {
            copy[r][c] = board[r][c];
        }
    }
    return copy;
}

function matchLine(oldLine, newLine) {
    let oldTiles = [];
    for (let i = 0; i < grid; i++) {
        if (oldLine[i] !== 0) {
            oldTiles.push({val: oldLine[i], pos: i});
        }
    }

    let newTiles = [];
    for (let i = 0; i < grid; i++) {
        if (newLine[i] !== 0) {
            newTiles.push({val: newLine[i], pos: i});
        }
    }

    let result = [];
    let oi = 0;
    let ni = 0;

    while (oi < oldTiles.length && ni < newTiles.length) {
        let ot = oldTiles[oi];
        let nt = newTiles[ni];

        if (nt.val === ot.val) {
            result.push({from: ot.pos, to: nt.pos, value: nt.val, merged: false, mergeFrom: 0});
            oi++;
            ni++;
        } else if (oi + 1 < oldTiles.length &&
                   oldTiles[oi + 1].val === ot.val &&
                   nt.val === ot.val * 2) {
            result.push({
                from: ot.pos,
                mergeFrom: oldTiles[oi + 1].pos,
                to: nt.pos,
                value: nt.val,
                merged: true
            });
            oi = oi + 2;
            ni++;
        } else {
            oi++;
        }
    }
    return result;
}

function findMergeCells(oldBoard, dir) {
    mergeCells = [];

    if (dir === 0) {
        for (let r = 0; r < grid; r++) {
            let oldRow = [oldBoard[r][0], oldBoard[r][1], oldBoard[r][2], oldBoard[r][3]];
            let newRow = [board[r][0], board[r][1], board[r][2], board[r][3]];
            let matches = matchLine(oldRow, newRow);
            for (let i = 0; i < matches.length; i++) {
                if (matches[i].merged) {
                    mergeCells.push({r: r, c: matches[i].to, value: matches[i].value});
                }
            }
        }
    } else if (dir === 1) {
        for (let r = 0; r < grid; r++) {
            let oldRow = [];
            for (let c = grid - 1; c >= 0; c--) oldRow.push(oldBoard[r][c]);
            let newRow = [];
            for (let c = grid - 1; c >= 0; c--) newRow.push(board[r][c]);
            let matches = matchLine(oldRow, newRow);
            for (let i = 0; i < matches.length; i++) {
                if (matches[i].merged) {
                    mergeCells.push({r: r, c: grid - 1 - matches[i].to, value: matches[i].value});
                }
            }
        }
    } else if (dir === 2) {
        for (let c = 0; c < grid; c++) {
            let oldCol = [oldBoard[0][c], oldBoard[1][c], oldBoard[2][c], oldBoard[3][c]];
            let newCol = [board[0][c], board[1][c], board[2][c], board[3][c]];
            let matches = matchLine(oldCol, newCol);
            for (let i = 0; i < matches.length; i++) {
                if (matches[i].merged) {
                    mergeCells.push({r: matches[i].to, c: c, value: matches[i].value});
                }
            }
        }
    } else if (dir === 3) {
        for (let c = 0; c < grid; c++) {
            let oldCol = [];
            for (let r = grid - 1; r >= 0; r--) oldCol.push(oldBoard[r][c]);
            let newCol = [];
            for (let r = grid - 1; r >= 0; r--) newCol.push(board[r][c]);
            let matches = matchLine(oldCol, newCol);
            for (let i = 0; i < matches.length; i++) {
                if (matches[i].merged) {
                    mergeCells.push({r: grid - 1 - matches[i].to, c: c, value: matches[i].value});
                }
            }
        }
    }
}

function drawPulseTile(x, y, value, scale) {
    let v = math.floor(value);
    let size = math.floor((cellSize - pad * 2) * scale);
    let offset = math.floor((cellSize - pad * 2 - size) / 2);
    let bg = tileColor(v);
    display.fill_rect(x + pad + offset, y + pad + offset, size, size, bg);

    display.set_text_size(1);
    if (v <= 4) {
        display.set_text_color(display.color565(119, 110, 101));
    } else {
        display.set_text_color(colors.white);
    }
    let digits = digitCount(v);
    let textW = digits * 6;
    let textH = 8;
    let tileCenterX = x + pad + offset + math.floor(size / 2);
    let tileCenterY = y + pad + offset + math.floor(size / 2);
    let cx = tileCenterX - math.floor(textW / 2);
    let cy = tileCenterY - math.floor(textH / 2) + 2;
    display.set_cursor(cx, cy);
    printTileNum(v);
}

function drawTile(x, y, value) {
    let v = math.floor(value);
    let bg = tileColor(v);
    display.fill_rect(x + pad, y + pad, cellSize - pad * 2, cellSize - pad * 2, bg);

    display.set_text_size(1);
    if (v <= 4) {
        display.set_text_color(display.color565(119, 110, 101));
    } else {
        display.set_text_color(colors.white);
    }
    let digits = digitCount(v);
    let textW = digits * 6;
    let textH = 8;
    let cx = x + math.floor((cellSize - textW) / 2);
    let cy = y + math.floor((cellSize - textH) / 2) + 2;
    display.set_cursor(cx, cy);
    printTileNum(v);
}

function drawHUD() {
    let boardColor = display.color565(250, 248, 239);
    let darkColor = display.color565(119, 110, 101);

    display.fill_rect(0, 0, w, gridY, boardColor);

    display.set_text_size(1);
    display.set_text_color(darkColor);
    display.set_cursor(textPad, statusBar + 4);
    display.print("Score: ");
    printNum(score);

    display.fill_rect(w - 160, statusBar + 4, 152, 8, boardColor);
    display.set_cursor(w - 150, statusBar + 4);
    display.set_text_color(darkColor);
    display.print("Best: ");
    printNum(state.highScore);

    display.fill_rect(textPad, statusBar + 14, 170, 8, boardColor);
    if (won) {
        display.set_cursor(textPad, statusBar + 14);
        display.set_text_color(display.color565(237, 194, 46));
        display.print("You win! A=continue");
    }
    if (gameOver) {
        display.set_cursor(textPad, statusBar + 14);
        display.set_text_color(colors.red);
        display.print("Game Over! A=new game");
    }

    display.set_cursor(textPad, h - 10);
    display.set_text_color(darkColor);
    display.print("Start=exit");
}

function drawFullBoard() {
    display.fill_screen(display.color565(250, 248, 239));

    for (let r = 0; r < grid; r++) {
        for (let c = 0; c < grid; c++) {
            let value = board[r][c];
            if (value !== 0) {
                drawTile(cellX(c), cellY(r), value);
            } else {
                display.fill_rect(cellX(c) + pad, cellY(r) + pad, cellSize - pad * 2, cellSize - pad * 2, display.color565(205, 193, 180));
            }
        }
    }

    drawHUD();
    drawFPS();
}

function drawPulseFrame() {
    let elapsed = util.time() - pulseStartTime;
    let t = elapsed / PULSE_DURATION;
    if (t > 1) t = 1;

    let scale;
    if (t < 0.25) {
        let p = t / 0.25;
        scale = 1 + 0.12 * (1 - (1 - p) * (1 - p));
    } else {
        let p = (t - 0.25) / 0.75;
        scale = 1 + 0.12 * (1 - p) * (1 - p);
    }

    for (let i = 0; i < mergeCells.length; i++) {
        let cell = mergeCells[i];
        drawPulseTile(cellX(cell.c), cellY(cell.r), cell.value, scale);
    }
}

function moveLeft() {
    moveDir = 0;
    let oldBoard = copyBoard();
    for (let r = 0; r < grid; r++) {
        let row = [board[r][0], board[r][1], board[r][2], board[r][3]];
        row = processRow(row);
        board[r][0] = row[0]; board[r][1] = row[1]; board[r][2] = row[2]; board[r][3] = row[3];
    }
    if (didBoardChange(oldBoard, board)) { prevBoard = oldBoard; return true; }
    return false;
}

function moveRight() {
    moveDir = 1;
    let oldBoard = copyBoard();
    for (let r = 0; r < grid; r++) {
        let row = [board[r][3], board[r][2], board[r][1], board[r][0]];
        row = processRow(row);
        board[r][0] = row[3]; board[r][1] = row[2]; board[r][2] = row[1]; board[r][3] = row[0];
    }
    if (didBoardChange(oldBoard, board)) { prevBoard = oldBoard; return true; }
    return false;
}

function moveUp() {
    moveDir = 2;
    let oldBoard = copyBoard();
    for (let c = 0; c < grid; c++) {
        let row = [board[0][c], board[1][c], board[2][c], board[3][c]];
        row = processRow(row);
        board[0][c] = row[0]; board[1][c] = row[1]; board[2][c] = row[2]; board[3][c] = row[3];
    }
    if (didBoardChange(oldBoard, board)) { prevBoard = oldBoard; return true; }
    return false;
}

function moveDown() {
    moveDir = 3;
    let oldBoard = copyBoard();
    for (let c = 0; c < grid; c++) {
        let row = [board[3][c], board[2][c], board[1][c], board[0][c]];
        row = processRow(row);
        board[0][c] = row[3]; board[1][c] = row[2]; board[2][c] = row[1]; board[3][c] = row[0];
    }
    if (didBoardChange(oldBoard, board)) { prevBoard = oldBoard; return true; }
    return false;
}

function resetGame() {
    for (let r = 0; r < grid; r++) {
        for (let c = 0; c < grid; c++) {
            board[r][c] = 0;
        }
    }
    score = 0;
    gameOver = false;
    won = false;
    mergeCells = [];
    animating = false;
    prevBoard = null;
    addRandomTile();
    addRandomTile();
}

resetGame();

let running = true;
let queuedDir = -1;

while (running) {
    let ctrl = controller.get_state();

    if (ctrl.start.just_pressed) {
        state.save();
        running = false;
    }

    if (ctrl.a.just_pressed && (gameOver || won)) {
        resetGame();
    }

    if (ctrl.left.just_pressed) {
        queuedDir = 0;
    }
    if (ctrl.right.just_pressed) {
        queuedDir = 1;
    }
    if (ctrl.up.just_pressed) {
        queuedDir = 2;
    }
    if (ctrl.down.just_pressed) {
        queuedDir = 3;
    }

    if (animating) {
        drawFullBoard();
        drawPulseFrame();
        display.queue_draw();

        if (util.time() - pulseStartTime >= PULSE_DURATION || queuedDir >= 0) {
            animating = false;
            mergeCells = [];
            if (!canMove()) {
                gameOver = true;
            }
        }
        util.sleep(0.003);
    } else if (!gameOver) {
        let moved = false;
        if (queuedDir >= 0) {
            if (queuedDir === 0) {
                moved = moveLeft();
            }
            if (queuedDir === 1) {
                moved = moveRight();
            }
            if (queuedDir === 2) {
                moved = moveUp();
            }
            if (queuedDir === 3) {
                moved = moveDown();
            }
            queuedDir = -1;
        }

        if (moved) {
            findMergeCells(prevBoard, moveDir);
            addRandomTile();
            if (mergeCells.length > 0) {
                pulseStartTime = util.time();
                animating = true;
            }
            if (score > state.highScore) {
                state.highScore = score;
            }
        }
        drawFullBoard();
        display.queue_draw();
        util.sleep(0.003);
    } else {
        drawFullBoard();
        display.queue_draw();
        util.sleep(0.003);
    }

    trackFPS();
}
