module source.app;

import parin;
import source.globals;

// TODO: Fix tile pick bug at borders.
// TODO: Make one more viewport for the map.

void ready() {
    atlas = loadTexture("atlas.png");
    foreach (ref map; maps) {
        map = TileMap(16, 16);
    }
    tileSetViewport.color = black;
    tileSetViewport.resize(256, resolutionHeight);
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
    auto mapMousePosition = mouse.toWorldPoint(tileMapCamera);
    auto mapMouseTileGridPosition = floor(mapMousePosition / maps[activeMap].tileSize);
    auto mapMouseTilePosition = maps[activeMap].tileSize * mapMouseTileGridPosition;
    auto setMousePosition = mouse.toWorldPoint(tileSetCamera, tileSetViewport);
    auto setMouseTileGridPosition = floor(setMousePosition / maps[activeMap].tileSize);
    auto setMouseTilePosition = maps[activeMap].tileSize * setMouseTileGridPosition;
    auto isInMapViewport = mouse.x > tileSetViewport.width + tileSetViewport.handleWidth;
    auto isIntileSetViewport = mouse.x < tileSetViewport.width;

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

    if (!tileSetViewport.isHandleActive) {
        if (isIntileSetViewport) {
            // Move the camera.
            tileSetCamera.update(dt);
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
            tileMapCamera.update(dt);
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

    tileMapCamera.attach();
    drawRect(Rect(maps[activeMap].size), black.alpha(30));
    foreach (map; maps) {
        drawTileMap(atlas, map, tileMapCamera);
    }
    if (!tileSetViewport.isHandleActive && isInMapViewport && maps[activeMap].has(mapMouseTileGridPosition.toIVec())) {
        drawTile(
            atlas,
            Tile(maps[activeMap].tileWidth, maps[activeMap].tileHeight, targetTile, mapMouseTilePosition),
        );
    }
    tileMapCamera.detach();
    tileSetViewport.draw();
    return false;
}

void finish() { }

mixin runGame!(ready, update, finish);
