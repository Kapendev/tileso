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
    if (!atlas.isValid) {
        drawDebugText("Add a \"atlas.png\" file inside the assets folder.", Vec2(8));
        return false;
    }

    // Some basic info.
    auto setSplitterHandle = Rect(setViewport.width, 0, setViewportHandleWidth, setViewport.height);
    auto setRowCount = atlas.width / maps[activeMap].tileWidth;
    auto setColCount = atlas.height / maps[activeMap].tileHeight;
    auto mousePosition = mouseScreenPosition;
    auto mapMousePosition = mouseWorldPosition(mapCamera);
    auto mapMouseTileGridPosition = floor(mapMousePosition / maps[activeMap].tileSize);
    auto mapMouseTilePosition = maps[activeMap].tileSize * mapMouseTileGridPosition;
    auto setMousePosition = mouseWorldPosition(setCamera);
    auto setMouseTileGridPosition = floor(setMousePosition / maps[activeMap].tileSize);
    auto setMouseTilePosition = maps[activeMap].tileSize * setMouseTileGridPosition;
    auto isInMapViewport = mousePosition.x > setViewport.width + setViewportHandleWidth;
    auto isInSetViewport = mousePosition.x < setViewport.width;

    // Resize the set viewport if needed.
    if (isWindowResized) {
        setViewport.resize(setViewportWidth, resolutionHeight);
    }

    if (Mouse.left.isPressed && setSplitterHandle.hasPoint(mousePosition)) {
        isSetViewportHandleActive = true;
    }
    if (isSetViewportHandleActive) {
        if (Mouse.left.isReleased) {
            isSetViewportHandleActive = false;
        }
        auto delta = deltaMouse;
        if (delta.x != 0) {
            setViewportWidth += cast(int) delta.x;
            setViewport.resize(setViewportWidth, resolutionHeight);
            setSplitterHandle = Rect(setViewport.width, 0, setViewportHandleWidth, setViewport.height);
        }
    }

    // Some basic keys.
    if (Keyboard.esc.isPressed) return true;
    if (Keyboard.f11.isPressed) toggleIsFullscreen();

    // Get the current target tile id.
    foreach (i, digit; digitChars[1 .. $]) {
        if (digit.isPressed) activeTileColOffset = i;
    }
    if ('c'.isPressed) activeTileRowOffset = wrap(activeTileRowOffset + 1, 0, 3);
    auto targetTile = activeTile + activeTileColOffset + (activeTileRowOffset * setColCount);

    if (!isSetViewportHandleActive) {
        if (isInSetViewport) {
            // Move the camera.
            setCamera.position += wasd * Vec2(mapCameraSpeed * dt);
            setCamera.scale += deltaWheel * setCameraZoomSpeed * dt;
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
            mapCamera.position += wasd * Vec2(mapCameraSpeed * dt);
            mapCamera.scale += deltaWheel * mapCameraZoomSpeed * dt;
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

    setViewport.attach();
    setCamera.attach();
    drawTexture(atlas, Vec2());
    drawRect(
        Rect(maps[activeMap].tileWidth * (targetTile % setColCount), maps[activeMap].tileHeight * (targetTile / setRowCount), maps[activeMap].tileSize),
        yellow.alpha(120),
    );
    setCamera.detach();
    setViewport.detach();

    mapCamera.attach();
    drawRect(Rect(maps[activeMap].size), black.alpha(60));
    foreach (map; maps) {
        drawTileMap(atlas, map, mapCamera);
    }
    if (!isSetViewportHandleActive && isInMapViewport && maps[activeMap].has(mapMouseTileGridPosition.toIVec())) {
        drawTile(
            atlas,
            Tile(maps[activeMap].tileWidth, maps[activeMap].tileHeight, targetTile, mapMouseTilePosition),
        );
    }
    mapCamera.detach();

    drawRect(setSplitterHandle, isSetViewportHandleActive ? white.alpha(120) : black.alpha(120));
    drawViewport(setViewport, Vec2());
    return false;
}

void finish() { }

mixin runGame!(ready, update, finish);
