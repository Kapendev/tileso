module source.globals;

import parin;

FontId font;
Canvas canvas;
TextureId atlas;
TileMap[4] maps;

int activeMap;
MapSize commonMapSize;
TileSize commonTileSize = TileSize.x16;

IVec2 activeTileStartPoint = IVec2(-1);
IVec2 activeTileEndPoint = IVec2(-1);
IVec2 activeTileOffset;

IVec2 copyPasteStartPoint = IVec2(-1);
IVec2 copyPasteEndPoint = IVec2(-1);
IVec2 copyPasteBufferSize;

IVec2 lastPlacedPoint = IVec2(-1);
short[TileMap.maxCapacity] copyPasteBuffer;

Tool activeTool;
UiOptions uiButtonOptions;

bool isSaving;
bool isLoading;

int[5] baseMapSizes = [16, 32, 64, 128, 256];

enum slowdown = 0.08f;
enum defaultMoveSpeed = 500;
enum defaultZoomSpeed = 15;
enum defaultHandleWidth = 20;

enum Tool {
    brush,
    eraser,
    rectangle,
    mix,
}

enum MapSize {
    tiny,
    small,
    medium,
    large,
    huge,
}

enum TileSize {
    x4,
    x8,
    x16,
    x24,
    x32,
    x48,
    x64,
}

struct ViewportMouse {
    Vec2 world;
    IVec2 grid;

    Vec2 worldGrid() {
        return grid.toVec() * maps[activeMap].tileSize;
    }
}

struct ViewportCamera {
    Camera data;
    Vec2 targetPosition;
    float targetScale = 1.0f;
    int moveSpeed = defaultMoveSpeed;
    int zoomSpeed = defaultZoomSpeed;

    alias data this;

    void update(float dt, bool canMove) {
        if (canMove) {
            targetPosition += wasd.normalize() * Vec2(moveSpeed * dt);
            targetScale = max(targetScale + deltaWheel * zoomSpeed * dt, 0.1f);
        }
        followPositionWithSlowdown(targetPosition, slowdown);
        followScaleWithSlowdown(targetScale, slowdown);
    }
}

struct ViewportObject {
    Viewport data;
    ViewportCamera camera;
    Vec2 position;

    alias data this;

    Rect area() {
        return Rect(position, size);
    }

    ViewportMouse mouse() {
        auto result = ViewportMouse();
        result.world = parin.mouse.toWorldPoint(camera, data) - position / Vec2(camera.scale);
        result.grid = (result.world / maps[activeMap].tileSize).floor().toIVec();
        return result;
    }

    void attach() {
        if (data.isEmpty) return;
        data.attach();
        camera.attach();
    }

    void detach() {
        if (data.isEmpty) return;
        camera.detach();
        data.detach();
    }

    void draw() {
        drawViewport(data, position);
    }
}

struct Canvas {
    ViewportObject a;
    ViewportObject b;
    int handleWidth = defaultHandleWidth;

    bool isUserInA() {
        return mouse.x < a.width;
    }

    bool isUserInB() {
        return mouse.x >= a.width + handleWidth;
    }

    bool hasGridPointInA(IVec2 point) {
        return point.x >= 0 && point.x < tileSetColCount && point.y >= 0 && point.y < tileSetRowCount;
    }

    bool hasGridPointInB(IVec2 point) {
        return maps[activeMap].has(point);
    }

    int currentViewport() {
        if (isUserInA) return 0;
        if (isUserInB) return 1;
        return -1;
    }

    void resizeA(int width) {
        a.resize(width, windowHeight);
        b.resize(windowWidth - width - handleWidth, windowHeight);
        b.position.x = a.width + handleWidth;
    }

    void resizeB(int width) {
        a.resize(windowHeight - width - handleWidth, windowHeight);
        b.resize(width, windowHeight);
        b.position.x = a.width + handleWidth;
    }

    void ready() {
        a.color = black;
        a.camera.isCentered = true;
        a.color = defaultUiDisabledColor.alpha(255);
        b.color = gray;
        b.camera.isCentered = true;
        resizeA(300);
    }

    void update(float dt) {
        // Update the cameras.
        a.camera.update(dt, isUserInA && !Keyboard.space.isDown && !Keyboard.ctrl.isDown && !isSaving && !isLoading);
        b.camera.update(dt, isUserInB && !Keyboard.space.isDown && !Keyboard.ctrl.isDown && !isSaving && !isLoading);
        // Resize the viewports when the window is resized.
        if (isWindowResized) {
            if (windowWidth < a.width + handleWidth) resizeA(windowWidth - handleWidth);
            else resizeA(a.width);
        }
        // Resize the viewports when the handle is used.
        // NOTE: The handle stops to render when the left camera is really zoomed???
        // NOTE: Only for the left viewport?
        auto point = Vec2(a.width, 0.0f);
        if (uiDragHandle(Vec2(handleWidth, windowHeight), point, UiOptions(UiDragLimit.viewport))) {
            resizeA(cast(int) point.x);
        }
        auto rect = Rect(point, Vec2(handleWidth, windowHeight));
        drawRect(rect.subLeft(4), defaultUiDisabledColor.alpha(255));
        drawRect(rect.subRight(4), defaultUiDisabledColor.alpha(255));
        drawRect(rect.subTop(4), defaultUiDisabledColor.alpha(255));
        drawRect(rect.subBottom(4), defaultUiDisabledColor.alpha(255));
    }

    void draw() {
        a.draw();
        b.draw();
    }
}

IVec2 findTopLeftPoint(IVec2 a, IVec2 b) {
    auto result = a;
    if (result.x > b.x) result.x = b.x;
    if (result.y > b.y) result.y = b.y;
    return result;
}

void resetActiveTilePoints() {
    activeTileStartPoint = IVec2(-1);
    activeTileEndPoint = IVec2(-1);
}

void resetActiveTileState() {
    resetActiveTilePoints();
    activeTileOffset = IVec2();
}

void resetCopyPastePoints() {
    copyPasteStartPoint = IVec2(-1);
    copyPasteEndPoint = IVec2(-1);
}

void resetCopyPasteState() {
    resetCopyPastePoints();
    copyPasteBufferSize = IVec2();
}

void setActiveTilePoint(IVec2 point) {
    activeTileStartPoint = point;
    activeTileEndPoint = point;
    activeTileOffset = IVec2();
    resetCopyPasteState();
}

void setCopyPastePoint(IVec2 point) {
    copyPasteStartPoint = point;
    copyPasteEndPoint = point;
    copyPasteBufferSize = IVec2();
    resetActiveTileState();
}

bool hasValidActiveTileState() {
    return activeTileStartPoint != IVec2(-1);
}

bool canUseActiveTileOffset() {
    return hasValidActiveTileState && activeTileStartPoint == activeTileEndPoint;
}

bool canCopyTileFromTileSet() {
    return copyPasteStartPoint == copyPasteEndPoint && maps[activeMap][copyPasteStartPoint] >= 0;
}

bool canPlaceTiles() {
    auto point = canvas.b.mouse.grid;
    auto areaSize = abs(lastPlacedPoint - point) + IVec2(1);
    if (hasValidActiveTileState) {
        auto activeTileSize = abs(activeTileEndPoint - activeTileStartPoint) + IVec2(1);
        return lastPlacedPoint == point || areaSize.x > activeTileSize.x || areaSize.y > activeTileSize.y;
    } else {
        return lastPlacedPoint == point || areaSize.x > copyPasteBufferSize.x || areaSize.y > copyPasteBufferSize.y;
    }
}

IVec2 activeTileSize() {
    return abs(activeTileEndPoint - activeTileStartPoint) + IVec2(1);
}

IVec2 activeTileTargetPoint() {
    if (!hasValidActiveTileState) return IVec2(-1);

    auto result = IVec2();
    if (canUseActiveTileOffset) {
        result = activeTileStartPoint + activeTileOffset;
    }  else {
        result = findTopLeftPoint(activeTileStartPoint, activeTileEndPoint);
    }
    return result;
}

short activeTileTargetId() {
    auto temp = activeTileTargetPoint;
    return cast(short) (temp.x + temp.y * tileSetColCount);
}

int tileSetRowCount() {
    return atlas.height / maps[activeMap].tileHeight;
}

int tileSetColCount() {
    return atlas.width / maps[activeMap].tileWidth;
}

void useSelectTool() {
    auto point = canvas.a.mouse.grid;
    if (canvas.hasGridPointInA(point)) {
        if (Mouse.left.isPressed || Mouse.right.isPressed) {
            setActiveTilePoint(point);
        } else if (Mouse.left.isDown || Mouse.right.isDown) {
            activeTileEndPoint = point;
        }
    } else {
        if (Mouse.left.isPressed || Mouse.right.isPressed) {
            resetActiveTileState();
            resetCopyPasteState();
        }
    }
    resetCopyPastePoints();
}

void usePencilTool() {
    auto point = canvas.b.mouse.grid;
    if (canvas.hasGridPointInB(point)) {
        if (Mouse.right.isPressed) {
            setCopyPastePoint(point);
        } else if (Mouse.right.isDown) {
            copyPasteEndPoint = point;
        } else if (Mouse.right.isReleased) {
            if (canCopyTileFromTileSet) {
                auto id = maps[activeMap][point];
                setActiveTilePoint(IVec2(id % tileSetColCount, id / tileSetColCount));
            } else {
                copyPasteBufferSize = abs(copyPasteEndPoint - copyPasteStartPoint) + IVec2(1);
                auto isNegativeBuffer = true;
                auto topLeftPoint = findTopLeftPoint(copyPasteStartPoint, copyPasteEndPoint);
                foreach (y; 0 .. copyPasteBufferSize.y) {
                    foreach (x; 0 .. copyPasteBufferSize.x) {
                        auto id = maps[activeMap][topLeftPoint + IVec2(x, y)];
                        if (id >= 0) isNegativeBuffer = false;
                        copyPasteBuffer[x + y * copyPasteBufferSize.x] = id;
                    }
                }
                resetCopyPastePoints();
                if (isNegativeBuffer) copyPasteBufferSize = IVec2();
            }
        }

        if (hasValidActiveTileState) {
            auto activeTileSize = abs(activeTileEndPoint - activeTileStartPoint) + IVec2(1);
            if (Mouse.left.isPressed) {
                lastPlacedPoint = point;
            }
            if (Mouse.left.isDown && canPlaceTiles) {
                lastPlacedPoint = point;
                foreach (y; 0 .. activeTileSize.y) {
                    foreach (x; 0 .. activeTileSize.x) {
                        auto index = point + IVec2(x, y);
                        if (!maps[activeMap].has(index)) continue;
                        maps[activeMap][index] = cast(short) (activeTileTargetId + x + y * tileSetColCount);
                    }
                }
            }
        } else {
            if (Mouse.left.isPressed) {
                lastPlacedPoint = point;
            }
            if (Mouse.left.isDown && canPlaceTiles) {
                lastPlacedPoint = point;
                foreach (y; 0 .. copyPasteBufferSize.y) {
                    foreach (x; 0 .. copyPasteBufferSize.x) {
                        auto index = point + IVec2(x, y);
                        if (!maps[activeMap].has(index)) continue;
                        if (copyPasteBuffer[x + y * copyPasteBufferSize.x] < 0) continue;
                        maps[activeMap][index] = copyPasteBuffer[x + y * copyPasteBufferSize.x];
                    }
                }
            }
        }
    }
}

void useEraserTool() {
    auto point = canvas.b.mouse.grid;
    if (canvas.hasGridPointInB(point)) {
        if (Mouse.left.isDown) {
            maps[activeMap][point] = -1;
        }
    }
}
