module source.globals;

import parin;


Camera mapCamera;
Camera setCamera;
float mapCameraSpeed = 400.0f;
float setCameraSpeed = 400.0f;
float mapCameraZoomSpeed = 10.0f;
float setCameraZoomSpeed = 10.0f;

Viewport setViewport;
int setViewportWidth = 360;
float setViewportHandleWidth = 10.0f;
bool isSetViewportHandleActive;

TextureId atlas;
TileMap[4] maps;
Sz activeMap;
Sz activeTile;
Sz activeTileRowOffset;
Sz activeTileColOffset;
