module source.app;

import parin;
import source.globals;

// TODO: Just clean things. I was testing stuff.
// TODO: Add copy-paste with left click.

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

    // Check basic keys.
    if (Keyboard.esc.isPressed) return true;
    if (Keyboard.f11.isPressed) toggleIsFullscreen();
    if (Keyboard.n0.isPressed) maps[activeMap].fill(-1);
    // Get some basic info based on the current state.
    auto tileSetRowCount = atlas.width / maps[activeMap].tileWidth;
    auto tileSetColCount = atlas.height / maps[activeMap].tileHeight;
    auto activeTileTargetPoint = activeTilePoint;
    if (activeTilePoint == activeTileGroupPoint) {
        if (activeTilePoint != IVec2(-1)) {
            foreach (i, digit; digitChars[1 .. $]) {
                if (digit.isPressed) activeTileOffset.x = cast(int) i;
            }
            if ('c'.isPressed) activeTileOffset.y = wrap(activeTileOffset.y + 1, 0, 3);
            activeTileTargetPoint = activeTilePoint + activeTileOffset;
        }
    } else {
        if (activeTilePoint.x > activeTileGroupPoint.x) activeTileTargetPoint.x = activeTileGroupPoint.x;
        if (activeTilePoint.y > activeTileGroupPoint.y) activeTileTargetPoint.y = activeTileGroupPoint.y;
    }
    // Update and prepare the canvas.
    canvas.update(dt);

    if (!canvas.isHandleActive) {
        if (canvas.isUserInA) {
            // Select tiles.
            auto point = canvas.a.mouse.grid;
            auto hasPoint = point.x >= 0 && point.x < tileSetColCount && point.y >= 0 && point.y < tileSetRowCount;
            if (hasPoint) {
                if (Mouse.left.isPressed) {
                    activeTilePoint = point;
                    activeTileGroupPoint = point;
                    activeTileOffset = IVec2();
                } else if (Mouse.left.isDown) {
                    activeTileGroupPoint = point;
                } else if (Mouse.left.isReleased) {
                    debug println("Group: ", activeTilePoint, " .. ", activeTileGroupPoint);
                }
            } else {
                if (Mouse.left.isPressed) {
                    activeTileTargetPoint = IVec2(-1);
                    activeTilePoint = IVec2(-1);
                    activeTileGroupPoint = IVec2(-1);
                    activeTileOffset = IVec2();
                }
            }
        } else if (canvas.isUserInB) {
            // Add or remove tiles.
            auto point = canvas.b.mouse.grid;
            auto hasPoint = maps[activeMap].has(point);
            auto activeTileSize = abs(activeTileGroupPoint - activeTilePoint);
            auto activeTileTargetId = activeTileTargetPoint.x + activeTileTargetPoint.y * tileSetColCount;
            if (hasPoint) {
                if (activeTileTargetPoint != IVec2(-1)) {
                    if (Mouse.left.isPressed) {
                        lastPlacedPoint = point;
                        foreach (y; 0 .. activeTileSize.y + 1) {
                            foreach (x; 0 .. activeTileSize.x + 1) {
                                auto index = point + IVec2(x, y);
                                if (!maps[activeMap].has(index)) continue;
                                maps[activeMap][index] = cast(short) (activeTileTargetId + x + y * tileSetColCount);
                            }
                        }
                    } else if (Mouse.left.isDown) {
                        auto size = abs(lastPlacedPoint - point);
                        auto canPlace = size.x > activeTileSize.x || size.y > activeTileSize.y;
                        if (canPlace) {
                            lastPlacedPoint = point;
                            foreach (y; 0 .. activeTileSize.y + 1) {
                                foreach (x; 0 .. activeTileSize.x + 1) {
                                    auto index = point + IVec2(x, y);
                                    if (!maps[activeMap].has(index)) continue;
                                    maps[activeMap][point + IVec2(x, y)] = cast(short) (activeTileTargetId + x + y * tileSetColCount);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Draw inside viewport A.
    canvas.a.attach();
    {
        auto activeTileSize = abs(activeTileGroupPoint - activeTilePoint);
        auto activeTileArea = Rect(
            activeTilePoint.toVec() * maps[activeMap].tileSize,
            (activeTileSize + IVec2(1)).toVec() * maps[activeMap].tileSize,
        );
        if (activeTileGroupPoint.x - activeTilePoint.x < 0) {
            activeTileArea.position.x -= activeTileSize.x * maps[activeMap].tileWidth;
        }
        if (activeTileGroupPoint.y - activeTilePoint.y < 0) {
            activeTileArea.position.y -= activeTileSize.y * maps[activeMap].tileHeight;
        }
        drawRect(Rect(atlas.size).addAll(2), gray);
        drawTexture(atlas, Vec2());
        if (activeTileTargetPoint != IVec2(-1)) {
            drawRect(activeTileArea, yellow.alpha(120));
        }
    }
    canvas.a.detach();

    // Draw inside viewport B.
    canvas.b.attach();
    {
        drawRect(Rect(maps[activeMap].size), black.alpha(30));
        foreach (map; maps) {
            drawTileMap(atlas, map, canvas.b.camera);
        }
        if (!canvas.isHandleActive) {
            if (canvas.isUserInB) {
                auto point = canvas.b.mouse.grid;
                auto hasPoint = maps[activeMap].has(point);
                if (hasPoint) {
                    if (activeTileTargetPoint != IVec2(-1)) {
                        auto tile = Tile(maps[activeMap].tileWidth, maps[activeMap].tileHeight, 0);
                        auto activeTileSize = abs(activeTileGroupPoint - activeTilePoint);
                        auto activeTileTargetId = activeTileTargetPoint.x + activeTileTargetPoint.y * tileSetColCount;
                        foreach (y; 0 .. activeTileSize.y + 1) {
                            foreach (x; 0 .. activeTileSize.x + 1) {
                                auto index = point + IVec2(x, y);
                                if (!maps[activeMap].has(index)) continue;
                                tile.id = activeTileTargetId + x + y * tileSetColCount;
                                tile.position = (index).toVec() * maps[activeMap].tileSize;
                                drawTile(atlas, tile, DrawOptions(gray3));
                            }
                        }
                    }
                }
            }
        }
    }
    canvas.b.detach();

    // Draw inside window.
    canvas.draw();
    { // The 3x3 helper.
        drawRect(Rect(mouse + Vec2(50 - 2, 25 - 2), Vec2(16 * 3 + 2 * 2 + 4)), gray3);
        foreach (y; 0 .. 3) {
            foreach (x; 0 .. 3) {
                auto rect = Rect(x * 18, y * 18, 16, 16);
                // rect.position += tileSetViewport.handle.position + Vec2(24, 8);
                rect.position += mouse + Vec2(50, 25);
                auto color = ((activeTileOffset.y % 3) == y && (activeTileOffset.x % 3) == x) ? gray4 : black.alpha(200);
                drawRect(rect, color);
            }
        }
    }
    return false;
}

void finish() { }

mixin runGame!(ready, update, finish);
