module source.globals;

import parin;

enum setViewportWidth = 256;

Camera mapCamera;
Camera setCamera;
float mapCameraSpeed = 300.0f;
float setCameraSpeed = 300.0f;

Viewport setViewport;
TextureId atlas;

TileMap[4] maps;
Sz activeMap;
Sz activeTile;
Sz activeTileColOffset;
Sz activeTileRowOffset;
