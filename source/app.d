module source.app;

import parin;
import source.globals;

// TODO: Just clean things. I was testing stuff and things are a bit chaotic.
// TODO: Fix bug where drawing from the copy-paste buffer does not stop when the mouse is in A.

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

    // Update the canvas.
    canvas.update(dt);
    if (!canvas.isHandleActive) {
        if (canvas.isUserInA) {
            useSelectTool();
        } else if (canvas.isUserInB) {
            usePencilTool();
        }
    }

    // NOTE: Stopped here when I was refactoring stuff.
    // Draw inside viewport A.
    canvas.a.attach();
    {
        auto activeTileSize = abs(activeTileEndPoint - activeTileStartPoint) + IVec2(1);
        auto activeTileArea = Rect(
            activeTileStartPoint.toVec() * maps[activeMap].tileSize,
            activeTileSize.toVec() * maps[activeMap].tileSize,
        );
        auto targetTileArea = Rect(
            activeTileTargetPoint.toVec() * maps[activeMap].tileSize,
            maps[activeMap].tileSize,
        );
        if (activeTileEndPoint.x - activeTileStartPoint.x < 0) {
            activeTileArea.position.x -= (activeTileSize.x - 1) * maps[activeMap].tileWidth;
        }
        if (activeTileEndPoint.y - activeTileStartPoint.y < 0) {
            activeTileArea.position.y -= (activeTileSize.y - 1) * maps[activeMap].tileHeight;
        }
        drawRect(Rect(atlas.size).addAll(2), gray);
        drawTexture(atlas, Vec2());
        if (activeTileTargetPoint != IVec2(-1)) {
            drawRect(activeTileArea, yellow.alpha(120));
        }
        if (canUseActiveTileOffset) {
            drawRect(targetTileArea, white.alpha(120));
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
        } else if (copyPasteBufferSize != IVec2()) {
            auto point = canvas.b.mouse.grid;
            auto tile = Tile(maps[activeMap].tileWidth, maps[activeMap].tileHeight, 0);
            foreach (y; 0 .. copyPasteBufferSize.y) {
                foreach (x; 0 .. copyPasteBufferSize.x) {
                    auto index = point + IVec2(x, y);
                    if (!maps[activeMap].has(index)) continue;
                    tile.id = copyPasteBuffer[x + y * copyPasteBufferSize.x];
                    tile.position = (index).toVec() * maps[activeMap].tileSize;
                    drawTile(atlas, tile, DrawOptions(gray3));
                }
            }
        }
        if (canvas.isUserInB) {
            auto point = canvas.b.mouse.grid;
            auto hasPoint = maps[activeMap].has(point);
            if (hasPoint) {
                if (copyPasteStartPoint == IVec2(-1) && activeTileTargetPoint != IVec2(-1)) {
                    auto tile = Tile(maps[activeMap].tileWidth, maps[activeMap].tileHeight, 0);
                    auto activeTileSize = abs(activeTileEndPoint - activeTileStartPoint) + IVec2(1);
                    auto activeTileTargetId = activeTileTargetPoint.x + activeTileTargetPoint.y * tileSetColCount;
                    foreach (y; 0 .. activeTileSize.y) {
                        foreach (x; 0 .. activeTileSize.x) {
                            auto index = point + IVec2(x, y);
                            if (!maps[activeMap].has(index)) continue;
                            tile.id = cast(short) (activeTileTargetId + x + y * tileSetColCount);
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
