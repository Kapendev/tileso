module source.app;

import parin;
import source.globals;

void ready() {
    atlas = loadTexture("atlas.png");
    setViewport = Viewport(black);
    setViewport.resize(setViewportWidth, resolutionHeight);
    foreach (ref map; maps) {
        map = TileMap(16, 16);
    }
    mapCamera.isCentered = true;
}

bool update(float dt) {
    // Some basic info.
    auto setRowCount = atlas.width / maps[activeMap].tileWidth;
    auto setColCount = atlas.height / maps[activeMap].tileHeight;
    auto mapMousePosition = mouseWorldPosition(mapCamera);
    auto mapMouseTileGridPosition = floor(mapMousePosition / maps[activeMap].tileSize);
    auto mapMouseTilePosition = maps[activeMap].tileSize * mapMouseTileGridPosition;
    auto setMousePosition = mouseWorldPosition(setCamera);
    auto setMouseTileGridPosition = floor(setMousePosition / maps[activeMap].tileSize);
    auto setMouseTilePosition = maps[activeMap].tileSize * setMouseTileGridPosition;
    
    // Some basic keys.
    if (Keyboard.esc.isPressed) return true;
    if (Keyboard.f11.isPressed) toggleIsFullscreen();

    // Move the cameras.
    mapCamera.position += wasd * Vec2(mapCameraSpeed * dt);

    // Get the current target tile id.
    foreach (i, digit; digitChars[1 .. $]) {
        if (digit.isPressed) activeTileColOffset = i;
    }
    if ('c'.isPressed) activeTileRowOffset = wrap(activeTileRowOffset + 1, 0, 3);
    auto targetTileId = activeTile + activeTileColOffset + (activeTileRowOffset * setColCount);

    // Add and remove tiles from the map.
    if (maps[activeMap].has(mapMouseTileGridPosition.toIVec())) {
        if (Mouse.left.isDown) {
            maps[activeMap][mapMouseTileGridPosition.toIVec()] = cast(short) targetTileId;
        }
        if (Mouse.right.isDown) {
            maps[activeMap][mapMouseTileGridPosition.toIVec()] = -1;
        }
    }

    if (isWindowResized) {
        setViewport.resize(setViewportWidth, resolutionHeight);
    }
    setViewport.attach();
    drawTexture(atlas, Vec2());
    setViewport.detach();

    mapCamera.attach();
    drawRect(Rect(maps[activeMap].size), black.alpha(60));
    foreach (map; maps) {
        drawTileMap(atlas, map, mapCamera);
    }
    if (maps[activeMap].has(mapMouseTileGridPosition.toIVec())) {
        drawTile(
            atlas,
            Tile(maps[activeMap].tileWidth, maps[activeMap].tileHeight, targetTileId, mapMouseTilePosition),
        );
    }
    mapCamera.detach();

    drawRect(Rect(setViewport.size + Vec2(4, 0)), black.alpha(120));
    drawViewport(setViewport, Vec2());
    drawDebugText("FPS: {}".format(fps), Vec2(8));
    return false;
}

void finish() { }

mixin runGame!(ready, update, finish);
