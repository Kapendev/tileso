module source.globals;

import parin;
import source.config;

Canvas canvas;
TextureId atlas;
TileMap[4] maps;

short activeMap;
IVec2 activeTileStartPoint = IVec2(-1);
IVec2 activeTileEndPoint = IVec2(-1);
IVec2 activeTileOffset = IVec2(0);
IVec2 copyPasteStartPoint = IVec2(-1);
IVec2 copyPasteEndPoint = IVec2(-1);
IVec2 lastPlacedPoint = IVec2(-1);

short[TileMap.maxCapacity] copyPasteBuffer;
IVec2 copyPasteBufferSize;

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

    ViewportMouse mouse() {
        auto result = ViewportMouse();
        result.world = parin.mouse.toWorldPoint(camera, data) - position / Vec2(camera.scale);
        result.grid = (result.world / maps[activeMap].tileSize).floor().toIVec();
        return result;
    }

    void attach() {
        data.attach();
        camera.attach();
    }

    void detach() {
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
    float handleOffset = 0.0f;
    bool isHandleActive;

    Rect handle() {
        return Rect(a.width, 0, handleWidth, windowHeight);
    }

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
        b.color = gray;
        b.camera.isCentered = true;
        resizeA(256);
    }

    void update(float dt) {
        // Update the cameras.
        a.camera.update(dt, isUserInA);
        b.camera.update(dt, isUserInB);
        // Resize the viewports when the window is resized.
        if (isWindowResized) resizeA(a.width);
        // Check if the handle is pressed and move it. This will also resize the viewports.
        auto collisionHandle = handle;
        collisionHandle.position.x -= 1;
        collisionHandle.size.x += 1;
        if (Mouse.left.isPressed && collisionHandle.hasPoint(mouse)) {
            isHandleActive = true;
            handleOffset = handle.position.x - mouse.x;
        }
        if (isHandleActive) {
            if (Mouse.left.isReleased) {
                isHandleActive = false;
            } else if (deltaMouse.x != 0.0f) {
                resizeA(clamp(cast(int) (mouse.x + handleOffset), 0, windowWidth - handleWidth));
            }
        }
    }

    void draw() {
        a.draw();
        b.draw();
        if (isHandleActive) {
            drawRect(handle, gray4);
            drawRect(handle.subAll(3), black.alpha(200));
        } else {
            drawRect(handle, gray3);
            drawRect(handle.subAll(3), black.alpha(200));
        }
    }
}

void resetActiveTileState() {
    activeTileStartPoint = IVec2(-1);
    activeTileEndPoint = IVec2(-1);
    activeTileOffset = IVec2(0);
}

void resetCopyPasteState() {
    copyPasteStartPoint = IVec2(-1);
    copyPasteEndPoint = IVec2(-1);
}

bool hasValidActiveTileState() {
    return activeTileStartPoint != IVec2(-1);
}

bool canUseActiveTileOffset() {
    return hasValidActiveTileState && activeTileStartPoint == activeTileEndPoint;
}

IVec2 activeTileTargetPoint() {
    if (!hasValidActiveTileState) return IVec2(-1);

    auto result = IVec2();
    if (canUseActiveTileOffset) {
        result = activeTileStartPoint + activeTileOffset;
    }  else {
        result = activeTileStartPoint;
        if (result.x > activeTileEndPoint.x) result.x = activeTileEndPoint.x;
        if (result.y > activeTileEndPoint.y) result.y = activeTileEndPoint.y;
    }
    return result;
}

int tileSetRowCount() {
    return atlas.width / maps[activeMap].tileWidth;
}

int tileSetColCount() {
    return atlas.height / maps[activeMap].tileHeight;
}
