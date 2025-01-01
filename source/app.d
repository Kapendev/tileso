module source.app;

import parin;
import source.globals;

// TODO: Just clean things. I was testing stuff and things are a bit chaotic.
// TODO: Need to work on tools.
// TODO: Need to add way to save.
// TODO: Need to add ctrl-z and ctrl-y.
// TODO: Add none button for gamepad.
// NOTE: Maybe start/end points can be viewport related and not tool related.

void ready() {
//    defaultUiDisabledColor.a = 255;
//    defaultUiIdleColor.a = 255;
//    defaultUiHotColor.a = 255;
//    defaultUiActiveColor.a = 255;

    setUiClickAction(Keyboard.none);
    canvas.ready();

    // TODO: Lol, don't do it like that dude.
    auto tempTileSizeValue = cast(int) (commonTileSize.toStr()[1 .. $].toUnsigned().get());

    foreach (ref map; maps) {
        map = TileMap(tempTileSizeValue, tempTileSizeValue);
        map.softMaxRowCount = baseMapSizes[commonMapSize];
        map.softMaxColCount = baseMapSizes[commonMapSize];
    }
    font = loadFont("dmsans_regular.ttf", 32, 0, 33);
    font.get().setFilter(Filter.linear);
    uiButtonOptions.font = font;
    setIsUiActOnPress(true);
    setCanUseAssetsPath(false);

    if (envArgs.length) {
        auto mapCount = 0;
        foreach (path; envArgs) {
            if (path.endsWith("png")) {
                atlas.free();
                atlas = loadTexture(path);
                canvas.a.camera.position = atlas.size * Vec2(0.5f);
                canvas.a.camera.targetPosition = atlas.size * Vec2(0.5f);
            }
            if (atlas.value && (path.endsWith("csv") || path.endsWith("txt"))) {
                if (activeMap + mapCount >= maps.length) continue;
                auto map = &maps[activeMap + mapCount];
                map.parse(loadTempText(path).getOr(), hasValidActiveTileState, hasValidActiveTileState);
                foreach (size; baseMapSizes) {
                    if (size > map.softMaxRowCount && size > map.softMaxColCount) {
                        foreach (ref mapMap; maps) {
                            mapMap.softMaxRowCount = size;
                            mapMap.softMaxColCount = size;
                        }
                        break;
                    }
                }
                mapCount += 1;
            }
        }
    }

    canvas.a.camera.position = atlas.size * Vec2(0.5f);
    canvas.a.camera.targetPosition = atlas.size * Vec2(0.5f);
}

bool update(float dt) {
    prepareUi();
    setUiFocus(0);
    if (Keyboard.esc.isPressed) return true;
    if (Keyboard.f11.isPressed) toggleIsFullscreen();

    if (droppedFilePaths.length) {
        auto mapCount = 0;
        foreach (path; droppedFilePaths) {
            if (path.endsWith("png")) {
                atlas.free();
                atlas = loadTexture(path);
                canvas.a.camera.position = atlas.size * Vec2(0.5f);
                canvas.a.camera.targetPosition = atlas.size * Vec2(0.5f);
            }
            if (atlas.value && (path.endsWith("csv") || path.endsWith("txt"))) {
                if (activeMap + mapCount >= maps.length) continue;
                auto map = &maps[activeMap + mapCount];
                map.parse(loadTempText(path).getOr(), 16, 16);
                foreach (size; baseMapSizes) {
                    if (size > map.softMaxRowCount && size > map.softMaxColCount) {
                        foreach (ref mapMap; maps) {
                            mapMap.softMaxRowCount = size;
                            mapMap.softMaxColCount = size;
                        }
                        break;
                    }
                }
                mapCount += 1;
            }
        }
    }

    if (!atlas.isValid) {
        drawText(font, "Drag and drop an atlas texture.", (windowSize * Vec2(0.5f)).round(), DrawOptions(Hook.center));
        return false;
    }
    canvas.update(dt);

    // Check basic keys.
    if ('0'.isPressed) {
        if (Keyboard.space.isDown) {
            foreach (ref map; maps) {
                map.fill(-1);
            }
        } else {
            maps[activeMap].fill(-1);
        }
    }
    if (canUseActiveTileOffset) {
        if (Keyboard.space.isDown) {
            foreach (i, c; "qwe") {
                if (c.isPressed) activeTileOffset.x = cast(int) i;
            }
            if ('r'.isPressed) activeTileOffset.y = wrap(activeTileOffset.y + 1, 0, 3);
        } else {
            activeTileOffset = IVec2();
        }
    }

    // Update the canvas.
    if (activeTool != Tool.brush) {
        resetActiveTileState();
        resetCopyPasteState();
    }
    if (!isUiDragged) {
        if (canvas.isUserInA) {
            if (Mouse.left.isPressed && activeTool == Tool.eraser) activeTool = Tool.brush;
            final switch (activeTool) {
                case Tool.brush: useSelectTool(); break;
                case Tool.rectangle: break;
                case Tool.eraser: break;
                case Tool.mix: break;
            }
        } else if (canvas.isUserInB) {
            final switch (activeTool) {
                case Tool.brush: usePencilTool(); break;
                case Tool.rectangle: break;
                case Tool.eraser: useEraserTool(); break;
                case Tool.mix: break;
            }
        }
    }

    // NOTE: Stopped here when I was refactoring stuff.
    // Draw inside viewport A.
    canvas.a.attach();
    if (!canvas.a.isEmpty) {
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
        drawRect(Rect(atlas.size).addAll(2), defaultUiIdleColor.alpha(255));
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
    if (!canvas.b.isEmpty) {
        drawRect(Rect(maps[activeMap].size), white.alpha(60));
        foreach (i, map; maps) {
            drawTileMap(atlas, map, canvas.b.camera, DrawOptions(i == activeMap ? white : gray3));
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
        } else if (copyPasteBufferSize != IVec2() && canvas.isUserInB) {
            auto point = canvas.b.mouse.grid;
            auto tile = Tile(maps[activeMap].tileWidth, maps[activeMap].tileHeight, 0);
            foreach (y; 0 .. copyPasteBufferSize.y) {
                foreach (x; 0 .. copyPasteBufferSize.x) {
                    auto index = point + IVec2(x, y);
                    if (!maps[activeMap].has(index)) continue;
                    tile.id = copyPasteBuffer[x + y * copyPasteBufferSize.x];
                    tile.position = (index).toVec() * maps[activeMap].tileSize;
                    drawTile(atlas, tile, DrawOptions(gray4));
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
                    foreach (y; 0 .. activeTileSize.y) {
                        foreach (x; 0 .. activeTileSize.x) {
                            auto index = point + IVec2(x, y);
                            if (!maps[activeMap].has(index)) continue;
                            tile.id = cast(short) (activeTileTargetId + x + y * tileSetColCount);
                            tile.position = (index).toVec() * maps[activeMap].tileSize;
                            drawTile(atlas, tile, DrawOptions(gray4));
                        }
                    }
                }
            }
        }
    }
    canvas.b.detach();

    // Draw inside window.
    canvas.draw();
    static hh = 0.0f;
    auto buttonSize = Vec2(120, 40);

    setUiMargin(4);
    auto toolButtonSize = Vec2(buttonSize.x * 0.25f - uiMargin * 0.5f * 1.5f, buttonSize.y);
    setUiStartPoint(canvas.b.area.topLeftPoint + Vec2(0.0f, uiMargin));
    drawRect(Rect(uiStartPoint, buttonSize.x, hh).addAll(uiMargin), defaultUiDisabledColor.alpha(255));

    useUiLayout(Layout.h);
    if (uiButton(buttonSize, commonMapSize.toStr(), uiButtonOptions)) {
        commonMapSize = cast(MapSize) wrap(commonMapSize + 1, 0, commonMapSize.max + 1);
        foreach (ref map; maps) {
            map.softMaxRowCount = baseMapSizes[commonMapSize];
            map.softMaxColCount = baseMapSizes[commonMapSize];
        }
    }
    useUiLayout(Layout.h);
    if (uiButton(buttonSize, commonTileSize.toStr(), uiButtonOptions)) {
        resetActiveTileState();
        commonTileSize = cast(TileSize) wrap(commonTileSize + 1, 0, commonTileSize.max + 1);
        foreach (ref map; maps) {
            // TODO: Lol, don't do it like that dude.
            auto temp = cast(int) (commonTileSize.toStr()[1 .. $].toUnsigned().get());
            map.tileWidth = temp;
            map.tileHeight = temp;
        }
    }
    useUiLayout(Layout.h);
    foreach (i, c; "BERM") {
        if (activeTool == i) setUiFocus(cast(short) (uiState.itemId + 1)); // TODO: Make uiItemId function???
        if (uiButton(toolButtonSize, c.toStr(), uiButtonOptions) || (c.isPressed && !Keyboard.space.isDown)) {
            activeTool = cast(Tool) i;
        }
    }
    auto layerButtonSize = Vec2(buttonSize.x * 0.25f - uiMargin * 0.5f * 1.5f, buttonSize.y);
    useUiLayout(Layout.h);
    foreach (i, c; "1234") {
        auto tempOptions = uiButtonOptions;
        if (activeMap == i) setUiFocus(cast(short) (uiState.itemId + 1));
        if (uiButton(layerButtonSize, c.toStr(), tempOptions) || c.isPressed) {
            activeMap = cast(int) i;
        }
    }
    useUiLayout(Layout.h);
    hh = uiLayoutPoint.y - uiStartPoint.y - uiMargin;

    static lastInfoTextRect = Rect();
    setUiStartPoint(Vec2(uiMargin, uiMargin));
    if (hasValidActiveTileState && lastInfoTextRect.topRightPoint.x < canvas.b.position.x - canvas.handleWidth) {
        uiInfoText("[{}] {} | {}".format(activeTileTargetId, activeTileTargetPoint, activeTileSize));
        lastInfoTextRect = Rect(uiItemPoint, uiItemSize);
    }
    drawHollowRect(Rect(canvas.a.size + Vec2(4.0f, 0.0f)), 4, defaultUiDisabledColor);
    return false;
}

void finish() { }

void uiInfoText(IStr text) {
    auto temp = uiButtonOptions;
    temp.alignment = Alignment.left;
    temp.alignmentOffset = 4;
    auto textSize = measureTextSize(font, text) + Vec2(temp.alignmentOffset * 3, 0.0f);
    auto finalSize = Vec2(textSize.x, 40.0f);
    updateUiText(finalSize, text, temp);
    drawRect(Rect(uiItemPoint, uiItemSize), defaultUiDisabledColor);
    drawUiText(uiItemSize, text, uiItemPoint, temp);
}

mixin runGame!(ready, update, finish);
