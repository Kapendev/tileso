module source.app;

import parin;
import source.globals;

// TODO: Just clean things. I was testing stuff.
// TODO: Add copy-paste with left click.

void selectTileFromTileSet() {
    auto point = canvas.a.mouse.grid;
    if (canvas.hasGridPointInA(point)) {
        if (Mouse.left.isPressed) {
            activeTileStartPoint = point;
            activeTileEndPoint = point;
            activeTileOffset = IVec2(0);
            resetCopyPasteState();
        } else if (Mouse.left.isDown) {
            activeTileEndPoint = point;
        } else if (Mouse.left.isReleased) {
            debug println("Group: ", activeTileStartPoint, " .. ", activeTileEndPoint);
        }
    } else {
        if (Mouse.left.isPressed) {
            resetActiveTileState();
        }
    }
}

void ready() {
    foreach (ref map; maps) {
        map = TileMap(16, 16);
    }
    atlas = loadTexture("atlas.png");
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
    if (canUseActiveTileOffset) {
        foreach (i, digit; digitChars[1 .. $]) {
            if (digit.isPressed) activeTileOffset.x = cast(int) i;
        }
        if ('x'.isPressed) activeTileOffset.y = wrap(activeTileOffset.y - 1, 0, 3);
        if ('c'.isPressed) activeTileOffset.y = wrap(activeTileOffset.y + 1, 0, 3);
    }

    // Update and prepare the canvas.
    canvas.update(dt);
    if (!canvas.isHandleActive) {
        if (canvas.isUserInA) {
           selectTileFromTileSet();
        } else if (canvas.isUserInB) {
            // NOTE: Was working last time here.
            // Add or remove tiles.
            auto point = canvas.b.mouse.grid;
            if (canvas.hasGridPointInB(point)) {
                if (Mouse.right.isPressed) {
                    copyPasteStartPoint = point;
                    copyPasteEndPoint = point;
                    resetActiveTileState();
                } else if (Mouse.right.isDown) {
                    copyPasteEndPoint = point;
                } else if (Mouse.right.isReleased) {
                    if (canCopyTileFromTileSet) {
                        auto id = maps[activeMap][copyPasteStartPoint];
                        activeTileStartPoint = IVec2(id % tileSetColCount, id / tileSetColCount);
                        activeTileEndPoint = activeTileStartPoint;
                        activeTileOffset = IVec2(0);
                        resetCopyPasteState();
                    }
                    debug println("Buffer: ", copyPasteStartPoint, " .. ", copyPasteEndPoint);
                }

                if (copyPasteStartPoint == IVec2(-1) && activeTileTargetPoint != IVec2(-1)) {
                    auto activeTileSize = abs(activeTileEndPoint - activeTileStartPoint);
                    auto activeTileTargetId = activeTileTargetPoint.x + activeTileTargetPoint.y * tileSetColCount;
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
        auto activeTileSize = abs(activeTileEndPoint - activeTileStartPoint);
        auto activeTileArea = Rect(
            activeTileStartPoint.toVec() * maps[activeMap].tileSize,
            (activeTileSize + IVec2(1)).toVec() * maps[activeMap].tileSize,
        );
        if (activeTileEndPoint.x - activeTileStartPoint.x < 0) {
            activeTileArea.position.x -= activeTileSize.x * maps[activeMap].tileWidth;
        }
        if (activeTileEndPoint.y - activeTileStartPoint.y < 0) {
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
        if (copyPasteStartPoint != IVec2(-1)) {
            auto size = abs(copyPasteEndPoint - copyPasteStartPoint);
            auto area = Rect(
                copyPasteStartPoint.toVec() * maps[activeMap].tileSize,
                (size + IVec2(1)).toVec() * maps[activeMap].tileSize,
            );
            if (copyPasteEndPoint.x - copyPasteStartPoint.x < 0) {
                area.position.x -= size.x * maps[activeMap].tileWidth;
            }
            if (copyPasteEndPoint.y - copyPasteStartPoint.y < 0) {
                area.position.y -= size.y * maps[activeMap].tileHeight;
            }
            drawRect(area, yellow.alpha(120));
        }
        if (canvas.isUserInB) {
            auto point = canvas.b.mouse.grid;
            auto hasPoint = maps[activeMap].has(point);
            if (hasPoint) {
                if (copyPasteStartPoint == IVec2(-1) && activeTileTargetPoint != IVec2(-1)) {
                    auto tile = Tile(maps[activeMap].tileWidth, maps[activeMap].tileHeight, 0);
                    auto activeTileSize = abs(activeTileEndPoint - activeTileStartPoint);
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
