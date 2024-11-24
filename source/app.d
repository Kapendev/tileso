module source.app;

import parin;
import source.globals;

// TODO: Just clean things. I was testing stuff.
// TODO: Add checks for width and height of the current active tile. Can go outside of map. 

void ready() {
    atlas = loadTexture("atlas.png");
    foreach (ref map; maps) {
        map = TileMap(16, 16);
    }
    canvas.ready();
}

bool update(float dt) {
    if (!atlas.isValid) {
        drawDebugText("Add a \"atlas.png\" file inside the assets folder.", Vec2(8));
        return false;
    }

    // Some basic keys.
    if (Keyboard.esc.isPressed) return true;
    if (Keyboard.f11.isPressed) toggleIsFullscreen();
    if (Keyboard.n0.isPressed) maps[activeMap].fill(-1);

    // Some basic stuff.
    canvas.update(dt);
    auto setRowCount = atlas.width / maps[activeMap].tileWidth;
    auto setColCount = atlas.height / maps[activeMap].tileHeight;
    // Get the current target tile id.
    if (activeTileWidth == 1 && activeTileHeight == 1) {
        foreach (i, digit; digitChars[1 .. $]) {
            if (digit.isPressed) activeTileColOffset = cast(short) i;
        }
        if ('c'.isPressed) activeTileRowOffset = cast(short) wrap(activeTileRowOffset + 1, 0, 3);
    }
    auto targetTile = cast(short) (activeTile + activeTileColOffset + (activeTileRowOffset * setColCount));

    if (!canvas.isHandleActive) {
        if (canvas.isInA) {
            static isDragging = false; // TODO: Remove later.
            // Select a tile from the set.
            auto gridPoint = canvas.a.mouse.grid;
            auto hasPoint = gridPoint.x >= 0 && gridPoint.x < setColCount && gridPoint.y >= 0 && gridPoint.y < setRowCount;
            if (isDragging) {
                if (Mouse.left.isDown && hasPoint) {
                    activeTileWidth = cast(short) (gridPoint.x - (activeTile % setColCount) + 1);
                    activeTileHeight = cast(short) (gridPoint.y - (activeTile / setColCount) + 1);
                }
                // TODO: Clean this maybe.
                if (Mouse.left.isReleased) {
                    isDragging = false;
                    if (activeTileWidth <= 0) {
                        activeTileWidth *= -1;
                        activeTileWidth += 2;
                        activeTile -= activeTileWidth - 1;
                    }
                    if (activeTileHeight <= 0) {
                        activeTileHeight *= -1;
                        activeTileHeight += 2;
                        activeTile -= (activeTileHeight - 1) * setColCount;
                    }
                }
            } else {
                if (Mouse.left.isDown && hasPoint) {
                    isDragging = true;
                    activeTile = cast(short) (setColCount * gridPoint.y + gridPoint.x);
                    activeTileRowOffset = 0;
                    activeTileColOffset = 0;
                    activeTileWidth = 1;
                    activeTileHeight = 1;
                }
            }
        } else {
            static lastPlaceGridPoint = IVec2(); // TODO: Remove later.
            // Add or remove a tile from the map.
            auto gridPoint = canvas.b.mouse.grid;
            auto hasPoint = maps[activeMap].has(gridPoint);
            auto canPlace = lastPlaceGridPoint == IVec2() || abs(gridPoint.x - lastPlaceGridPoint.x) >= activeTileWidth || abs(gridPoint.y - lastPlaceGridPoint.y) >= activeTileHeight; // TODO: Remove later.
            if (Mouse.left.isDown && hasPoint && canPlace) {
                lastPlaceGridPoint = gridPoint;
                foreach (y; 0 .. activeTileHeight) {
                    foreach (x; 0 .. activeTileWidth) {
                        maps[activeMap][gridPoint + IVec2(x, y)] = cast(short) (targetTile + x + y * setColCount);
                    }
                }
            }
            if (Mouse.left.isReleased) {
                lastPlaceGridPoint = IVec2();
            }
            if (Mouse.right.isDown && hasPoint) {
                maps[activeMap][gridPoint] = -1;
                activeTileWidth = 1;
                activeTileHeight = 1;
            }
        }
    }

    // Draw stuff in a.
    canvas.a.attach();
    drawTexture(atlas, Vec2());
    {
        // Small hack maybe for drawing big areas right?
        // TODO: Clean this maybe.
        auto tempWidth = activeTileWidth;
        auto tempHeight = activeTileHeight;
        auto tempTile = activeTile;
        if (tempWidth <= 0) {
            tempWidth *= -1;
            tempWidth += 2;
            tempTile -= tempWidth - 1;
        }
        if (tempHeight <= 0) {
            tempHeight *= -1;
            tempHeight += 2;
            tempTile -= (tempHeight - 1) * setColCount;
        }
        drawRect(
            Rect(maps[activeMap].tileWidth * (tempTile % setColCount), maps[activeMap].tileHeight * (tempTile / setRowCount), maps[activeMap].tileSize * Vec2(tempWidth, tempHeight)),
            yellow.alpha(120),
        );
    }
    canvas.a.detach();

    // Draw stuff in b.
    canvas.b.attach();
    drawRect(Rect(maps[activeMap].size), black.alpha(30));
    foreach (map; maps) {
        drawTileMap(atlas, map, canvas.b.camera);
    }
    if (!canvas.isHandleActive && canvas.isInB && maps[activeMap].has(canvas.b.mouse.grid)) {
        auto tile = Tile(maps[activeMap].tileWidth, maps[activeMap].tileHeight, 0);
        foreach (y; 0 .. activeTileHeight) {
            foreach (x; 0 .. activeTileWidth) {
                tile.id = targetTile + x + y * setColCount;
                tile.position = canvas.b.mouse.worldGrid + Vec2(x, y) * maps[activeMap].tileSize;
                drawTile(atlas, tile, DrawOptions(gray3));
            }
        }
    }
    canvas.b.detach();

    // Draw stuff in window.
    canvas.draw();
    drawRect(Rect(mouse + Vec2(50 - 2, 25 - 2), Vec2(16 * 3 + 2 * 2 + 4)), gray3);
    foreach (y; 0 .. 3) {
        foreach (x; 0 .. 3) {
            auto rect = Rect(x * 18, y * 18, 16, 16);
            // rect.position += tileSetViewport.handle.position + Vec2(24, 8);
            rect.position += mouse + Vec2(50, 25);
            auto color = ((activeTileRowOffset % 3) == y && (activeTileColOffset % 3) == x) ? gray4 : black.alpha(200);
            drawRect(rect, color);
        }
    }
    return false;
}

void finish() { }

mixin runGame!(ready, update, finish);
