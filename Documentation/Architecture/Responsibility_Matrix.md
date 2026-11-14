# Responsibility Matrix

## Target

The project targets approximately 70% MATLAB and 30% Unity, measured by
computational and algorithmic responsibility, not by line count.
This matrix documents the actual distribution; it is not used to inflate code.

## MATLAB - computational and algorithmic side

| Area | Responsibility |
|---|---|
| 2D graphics | DDA and Bresenham line drawing, midpoint circle, rectangles, polygons, colored fill |
| 2D transformations | Translation, rotation, scaling, reflection, shearing, homogeneous matrices |
| 2D clipping | Cohen-Sutherland line clipping |
| 3D geometry | Cube, sphere and cylinder generated from coordinates and equations |
| 3D transformations | Translation, rotation around X/Y/Z, scaling, 4x4 matrices, transformation order |
| Lighting | Face and vertex normals, ambient, diffuse and specular components, Lambert and Phong shading |
| Projection | Orthographic and perspective projection matrices |
| Export | Mesh vertices, face indices and OBJ output for Unity |
| Interaction mapping | Mouse coordinates to activity space, drop-target hit testing, snap positions |
| Activity content | Layout generation for the color, taste and mathematics activities |
| Validation | Authoritative correctness checks for all three activities |
| Progression | Hints, scoring, difficulty management, star calculation, session state |
| Communication | TCP server, JSON encoding and decoding, message routing, request correlation |

## Unity - presentation side

| Area | Responsibility |
|---|---|
| Environment | Bedroom, furniture, props, lighting setup |
| Characters | Player and father models, animations |
| Interaction | Keyboard and mouse input collection, camera, interaction prompts |
| Presentation | UI, audio, visual feedback, ending cutscene |
| Networking | TCP client, connection status, automatic reconnection |
| Scenes | Scene management and transitions |

## Rules

- Unity never decides whether an answer is correct.
- Activity data and validation live in MATLAB.
- Unity renders only what MATLAB provides.
- Keyboard and mouse input are collected by Unity and sent to MATLAB for validation.
