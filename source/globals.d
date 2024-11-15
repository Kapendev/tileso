module source.globals;

import parin;

enum setViewportWidth = 360;

Camera mapCamera;
Camera setCamera;
float mapCameraSpeed = 400.0f;
float setCameraSpeed = 400.0f;
float mapCameraZoomSpeed = 10.0f;
float setCameraZoomSpeed = 10.0f;

Viewport setViewport;
Vec2 setViewportPosition;

TextureId atlas;
TileMap[4] maps;
Sz activeMap;
Sz activeTile;
Sz activeTileRowOffset;
Sz activeTileColOffset;
