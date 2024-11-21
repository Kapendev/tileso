module source.globals;

import parin;

enum slowdown = 0.08f;

Canvas canvas;
TextureId atlas;
TileMap[4] maps;
Sz activeMap;
Sz activeTile;
Sz activeTileRowOffset;
Sz activeTileColOffset;

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
    int moveSpeed = 400;
    int zoomSpeed = 12;

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
        result.grid = (result.world / maps[activeMap].tileSize).toIVec();
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
    int handleWidth = 16;
    float handleOffset = 0.0f;
    bool isHandleActive;

    Rect handle() {
        return Rect(a.width, 0, handleWidth, windowHeight);
    }

    bool isInA() {
        return mouse.x < a.width;
    }

    bool isInB() {
        return mouse.x >= a.width + handleWidth;
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
        // Move the cameras.
        a.camera.update(dt, isInA);
        b.camera.update(dt, isInB);
        // Resize the viewports when the window is resized.
        if (isWindowResized) {
            resizeA(a.width);
        }
        // Check if the handle is pressed and move it. This will also resize the viewports.
        if (Mouse.left.isPressed && handle.hasPoint(mouse)) {
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
