module source.globals;

import parin;

AppCamera tileMapCamera;
AppCamera tileSetCamera;
TileSetViewport tileSetViewport;

TextureId atlas;
TileMap[4] maps;
Sz activeMap;
Sz activeTile;
Sz activeTileRowOffset;
Sz activeTileColOffset;

struct AppCamera {
    Camera data;
    Vec2 targetPosition;
    float slowdown = 0.08f;
    float targetScale = 1.0f;
    int moveSpeed = 400;
    int zoomSpeed = 15;
    alias data this;

    void update(float dt) {
        targetPosition = targetPosition + wasd * Vec2(moveSpeed * dt);
        targetScale = max(targetScale + deltaWheel * zoomSpeed * dt, 0.1f);
        followPositionWithSlowdown(targetPosition, slowdown);
        followScaleWithSlowdown(targetScale, slowdown);
    }

    // TODO: Put something like that inside of parin.
    // NOTE: No idea how the API should look.
    void myAttach(Viewport viewport = Viewport()) {
        import rl = parin.rl;
    
        if (isAttached) return;
        isAttached = true;
        auto temp = this.toRl();
        // The hack.
        if (viewport.isEmpty) {
            temp.offset = (Vec2(tileSetViewport.width, 0) + Rect(resolutionWidth - tileSetViewport.width, resolutionHeight).origin(hook)).toRl();
        } else {
            temp.offset = Rect(viewport.width, viewport.height).origin(hook).toRl();
        }
        if (isPixelSnapped || isPixelPerfect) {
            temp.target.x = floor(temp.target.x);
            temp.target.y = floor(temp.target.y);
            temp.offset.x = floor(temp.offset.x);
            temp.offset.y = floor(temp.offset.y);
        }
        rl.BeginMode2D(temp);
    }
}

struct TileSetViewport {
    Viewport data;
    int handleWidth = 16;
    float handleMouseOffset = 0.0f;
    bool isHandleActive;
    alias data this;

    Rect handle() {
        return Rect(width, 0, handleWidth, height);
    }

    void update(float dt) {
        // The hack handle is used to make collision checking nicer.
        auto hackHandle = handle;
        hackHandle.position.x -= 1;
        hackHandle.size.x += 1;
        if (isWindowResized) resize(width, resolutionHeight);
        if (Mouse.left.isPressed && hackHandle.hasPoint(mouseScreenPosition)) {
            isHandleActive = true;
            handleMouseOffset = tileSetViewport.width - mouseScreenPosition.x;
        }
        if (isHandleActive) {
            if (Mouse.left.isReleased) {
                isHandleActive = false;
            } else if (deltaMouse.x != 0) {
                auto target = clamp(cast(int) (mouseScreenPosition.x + handleMouseOffset), 0, resolutionWidth - handleWidth);
                tileSetViewport.resize(target, resolutionHeight);
            }
        }
    }

    void draw() {
        if (isHandleActive) {
            drawRect(handle, gray4);
            drawRect(handle.subAll(3), black.alpha(200));
        } else {
            drawRect(handle, gray3);
            drawRect(handle.subAll(3), black.alpha(200));
        }
        drawViewport(data, Vec2());
    }
}
