module source.app;

import parin;
import source.globals;

// TODO: Just clean things. I was testing stuff and things are a bit chaotic.

void ready() {
    canvas.ready();
    foreach (ref map; maps) {
        map = TileMap(16, 16);
        map.softMaxRowCount = baseMapSizes[commonMapSize];
        map.softMaxColCount = baseMapSizes[commonMapSize];
    }
    font = loadRawFont("dmsans_regular.ttf", 32, 0, 33).getOr();
    font.setFilter(Filter.linear);
    if (font.isEmpty) {
        font = engineFont;
        println("No font found! Using the default engine font instead.");
    }
    uiButtonOptions.font = font;
    uiButtonOptions.disabledColor.a = 255;
    uiButtonOptions.idleColor.a = 255;
    uiButtonOptions.hotColor.a = 255;
    uiButtonOptions.activeColor.a = 255;
    setIsUiActOnPress(true);
    setCanUseAssetsPath(false);

    if (envArgs.length) {
        auto mapCount = 0;
        foreach (path; envArgs) {
            if (path.endsWith("png")) {
                atlas.free();
                atlas = loadTexture(path);
                canvas.a.camera.position = Vec2();
                canvas.a.camera.targetPosition = Vec2();
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
                canvas.a.camera.position = Vec2();
                canvas.a.camera.targetPosition = Vec2();
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
        if (Keyboard.alt.isDown) {
            foreach (ref map; maps) {
                map.fill(-1);
            }
        } else {
            maps[activeMap].fill(-1);
        }
    }
    if (canUseActiveTileOffset) {
        foreach (i, digit; digitChars[1 .. $]) {
            if (digit.isPressed) activeTileOffset.x = cast(int) i;
        }
        if ('x'.isPressed) activeTileOffset.y = wrap(activeTileOffset.y - 1, 0, 3);
        if ('c'.isPressed) activeTileOffset.y = wrap(activeTileOffset.y + 1, 0, 3);
    }

    // Update the canvas.
    if (activeTool == Tool.eraser) {
        resetActiveTileState();
        resetCopyPasteState();
    }
    if (!isUiDragged) {
        if (canvas.isUserInA) {
            if (Mouse.left.isPressed && activeTool == Tool.eraser) activeTool = Tool.pencil;
            if (activeTool != Tool.eraser) useSelectTool();
        } else if (canvas.isUserInB) {
            final switch (activeTool) {
                case Tool.pencil: usePencilTool(); break;
                case Tool.eraser: useEraserTool(); break;
            }
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
    setUiStartPoint(canvas.b.area.topLeftPoint + Vec2(uiMargin * 2));
    drawRect(Rect(uiStartPoint, buttonSize.x, hh).addAll(uiMargin), uiButtonOptions.disabledColor);

    useUiLayout(Layout.h);
    if (uiButton(buttonSize, activeTool.toStr(), uiButtonOptions)) {
        activeTool = cast(Tool) wrap(activeTool + 1, 0, Tool.max + 1);
    }
    useUiLayout(Layout.h);
    if (uiButton(buttonSize, commonMapSize.toStr(), uiButtonOptions)) {
        commonMapSize = cast(MapSize) wrap(commonMapSize + 1, 0, commonMapSize.max + 1);
        foreach (ref map; maps) {
            map.softMaxRowCount = baseMapSizes[commonMapSize];
            map.softMaxColCount = baseMapSizes[commonMapSize];
        }
    }
    auto layerButtonSize = Vec2(buttonSize.x * 0.25f - uiMargin * 0.5f * 1.5f, buttonSize.y);
    foreach (i; 0 .. maps.length) {
        if (i % 4 == 0) useUiLayout(Layout.h);
        if (uiButton(layerButtonSize, (i + 1).toStr(), uiButtonOptions)) {
            activeMap = cast(int) i;
        }
    }
    useUiLayout(Layout.h);
    hh = uiLayoutPoint.y - uiStartPoint.y - uiMargin;

    setUiStartPoint(canvas.a.area.topLeftPoint + Vec2(uiMargin));
    useUiLayout(Layout.v);
    if (hasValidActiveTileState && canvas.b.position.x - canvas.handleWidth > 170.0f) {
        auto activeTileSize = abs(activeTileEndPoint - activeTileStartPoint) + IVec2(1);
        uiInfoText("{}: {}".format(activeTileTargetPoint, activeTileTargetId));
        if (activeTileSize != IVec2(1)) uiInfoText("{}".format(activeTileSize));
    }
    return false;
}

void finish() { }

void uiInfoText(IStr text) {
    auto options = uiButtonOptions;
    options.alignment = Alignment.left;
    options.alignmentOffset = 6;

    auto size = measureTextSize(options.font, text) + Vec2(12.0f, uiMargin);

    updateUiText(size, text, uiButtonOptions);
    drawRect(Rect(uiItemPoint, uiItemSize), black);
    drawUiText(size, text, uiItemPoint, options);
}

mixin runGame!(ready, update, finish);
