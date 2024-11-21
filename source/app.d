module source.app;

import parin;
import source.globals;

// TODO: Just clean things. I was testing stuff.

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

    // Some basic stuff.
    canvas.update(dt);
    auto setRowCount = atlas.width / maps[activeMap].tileWidth;
    auto setColCount = atlas.height / maps[activeMap].tileHeight;
    // Get the current target tile id.
    foreach (i, digit; digitChars[1 .. $]) {
        if (digit.isPressed) activeTileColOffset = i;
    }
    if ('c'.isPressed) activeTileRowOffset = wrap(activeTileRowOffset + 1, 0, 3);
    auto targetTile = activeTile + activeTileColOffset + (activeTileRowOffset * setColCount);

    if (!canvas.isHandleActive) {
        if (canvas.isInA) {
            // Select a tile from the set.
            auto gridPoint = canvas.a.mouse.grid;
            auto hasPoint = gridPoint.x >= 0 && gridPoint.x < setColCount && gridPoint.y >= 0 && gridPoint.y < setRowCount;
            if (Mouse.left.isDown && hasPoint) {
                activeTile = cast(short) (setColCount * gridPoint.y + gridPoint.x);
                activeTileRowOffset = 0;
                activeTileColOffset = 0;
            }
        } else {
            // Add or remove a tile from the map.
            auto gridPoint = canvas.b.mouse.grid;
            auto hasPoint = maps[activeMap].has(gridPoint);
            if (Mouse.left.isDown && hasPoint) {
                maps[activeMap][gridPoint] = cast(short) targetTile;
            }
            if (Mouse.right.isDown && hasPoint) {
                maps[activeMap][gridPoint] = -1;
            }
        }
    }

    // Draw stuff in a.
    canvas.a.attach();
    drawTexture(atlas, Vec2());
    drawRect(
        Rect(maps[activeMap].tileWidth * (targetTile % setColCount), maps[activeMap].tileHeight * (targetTile / setRowCount), maps[activeMap].tileSize),
        yellow.alpha(120),
    );
    canvas.a.detach();

    // Draw stuff in b.
    canvas.b.attach();
    drawRect(Rect(maps[activeMap].size), black.alpha(30));
    foreach (map; maps) {
        drawTileMap(atlas, map, canvas.b.camera);
    }
    if (!canvas.isHandleActive && canvas.isInB && maps[activeMap].has(canvas.b.mouse.grid)) {
        drawTile(
            atlas,
            Tile(maps[activeMap].tileWidth, maps[activeMap].tileHeight, targetTile, canvas.b.mouse.worldGrid),
            DrawOptions(gray3),
        );
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
