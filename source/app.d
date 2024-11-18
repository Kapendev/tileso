module source.app;

import parin;
import source.globals;

// TODO: Fix tile pick bug at borders.
// TODO: Just clean things. I was testing stuff.

void ready() {
    atlas = loadTexture("atlas.png");
    foreach (ref map; maps) {
        map = TileMap(16, 16);
    }
    tileSetViewport.color = black;
    tileSetViewport.resize(256, resolutionHeight);
    tileMapViewport.resize(resolutionWidth - 256 - tileSetViewport.handleWidth, resolutionHeight);
    tileMapCamera.isCentered = true;
    tileSetCamera.isCentered = true;
    tileSetCamera.targetPosition = atlas.size * Vec2(0.5f);
    tileSetCamera.position = tileSetCamera.targetPosition;
}

bool update(float dt) {
    if (!atlas.isValid) {
        drawDebugText("Add a \"atlas.png\" file inside the assets folder.", Vec2(8));
        return false;
    }

    // Some basic info.
    auto setRowCount = atlas.width / maps[activeMap].tileWidth;
    auto setColCount = atlas.height / maps[activeMap].tileHeight;
    auto mapMousePosition = mouse.toWorldPoint(tileMapCamera, tileMapViewport) - Vec2((tileSetViewport.width + tileSetViewport.handleWidth) / tileMapCamera.scale, 0);
    auto mapMouseTileGridPosition = floor(mapMousePosition / maps[activeMap].tileSize);
    auto mapMouseTilePosition = maps[activeMap].tileSize * mapMouseTileGridPosition;
    auto setMousePosition = mouse.toWorldPoint(tileSetCamera, tileSetViewport);
    auto setMouseTileGridPosition = floor(setMousePosition / maps[activeMap].tileSize);
    auto setMouseTilePosition = maps[activeMap].tileSize * setMouseTileGridPosition;
    auto isInMapViewport = mouse.x > tileSetViewport.width + tileSetViewport.handleWidth;
    auto isInTileSetViewport = mouse.x < tileSetViewport.width;

    // Resize the set viewport if needed.
    tileSetViewport.update(dt);

    // Some basic keys.
    if (Keyboard.esc.isPressed) return true;
    if (Keyboard.f11.isPressed) toggleIsFullscreen();

    // Get the current target tile id.
    foreach (i, digit; digitChars[1 .. $]) {
        if (digit.isPressed) activeTileColOffset = i;
    }
    if ('c'.isPressed) activeTileRowOffset = wrap(activeTileRowOffset + 1, 0, 3);
    auto targetTile = activeTile + activeTileColOffset + (activeTileRowOffset * setColCount);

    tileSetCamera.update(dt, isInTileSetViewport);
    tileMapCamera.update(dt, isInMapViewport);
    if (!tileSetViewport.isHandleActive) {
        if (isInTileSetViewport) {
            // Select a tile from the set.
            auto hasPoint =
                setMouseTileGridPosition.x >= 0 &&
                setMouseTileGridPosition.x <= setColCount &&
                setMouseTileGridPosition.y >= 0 &&
                setMouseTileGridPosition.y <= setRowCount;
            if (Mouse.left.isDown && hasPoint) {
                activeTile = cast(short) (setColCount * setMouseTileGridPosition.y + setMouseTileGridPosition.x);
                activeTileRowOffset = 0;
                activeTileColOffset = 0;
            }
        } else if (isInMapViewport) {
            // Move the camera.
            // Add or remove a tile from the map.
            auto hasPoint = maps[activeMap].has(mapMouseTileGridPosition.toIVec());
            if (Mouse.left.isDown && hasPoint) {
                maps[activeMap][mapMouseTileGridPosition.toIVec()] = cast(short) targetTile;
            }
            if (Mouse.right.isDown && hasPoint) {
                maps[activeMap][mapMouseTileGridPosition.toIVec()] = -1;
            }
        }
    }


    tileSetViewport.attach();
    tileSetCamera.attach();
    drawTexture(atlas, Vec2());
    drawRect(
        Rect(maps[activeMap].tileWidth * (targetTile % setColCount), maps[activeMap].tileHeight * (targetTile / setRowCount), maps[activeMap].tileSize),
        yellow.alpha(120),
    );
    tileSetCamera.detach();
    tileSetViewport.detach();

    tileMapViewport.attach();
    tileMapCamera.attach();
    drawRect(Rect(maps[activeMap].size), black.alpha(30));
    foreach (map; maps) {
        drawTileMap(atlas, map, tileMapCamera);
    }
    if (!tileSetViewport.isHandleActive && isInMapViewport && maps[activeMap].has(mapMouseTileGridPosition.toIVec())) {
        drawTile(
            atlas,
            Tile(maps[activeMap].tileWidth, maps[activeMap].tileHeight, targetTile, mapMouseTilePosition),
            DrawOptions(gray3),
        );
    }
    tileMapCamera.detach();
    tileMapViewport.detach();

    tileSetViewport.draw();
    drawViewport(tileMapViewport, Vec2(tileSetViewport.width + tileSetViewport.handleWidth, 0));
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
