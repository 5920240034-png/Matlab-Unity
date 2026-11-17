# 3D Geometric Objects: Cube, Sphere and Cylinder

**Issue #007 — implementation reference**

| Item | Value |
|---|---|
| Scope | 3D geometry generation in MATLAB (no Unity changes). |
| Package | `cmr.graphics` |
| Classes | `MATLAB/Graphics/+cmr/+graphics/Mesh3D.m`, `Cube3D.m`, `Sphere3D.m`, `Cylinder3D.m` |
| Demo | `MATLAB/Graphics/demo3DObjects.m` |
| Tests | `MATLAB/Tests/tMesh3D.m` (22), `MATLAB/Tests/t3DObjects.m` (25) |
| Mesh export | `Shared_Data/Meshes/cube.obj`, `sphere.obj`, `cylinder.obj` |
| Evidence | `Deliverables/Screenshots/Issue007_3D_Objects.png`, `Issue007_3D_Views.png`, `Issue007_3D_Mesh_Structure.png` |
| Test report | `Documentation/Testing/Issue007_Test_Report.md` |

---

## 1. Purpose and scope

`AGENTS.md` §7 requires MATLAB to generate 3D geometric objects from mathematical
definitions, not from Unity primitives. This module implements the Issue #007
primitives:

- **cube** — eight vertices and six outward-oriented quad faces;
- **sphere** — a parametric `(theta, phi)` surface evaluated from the sphere
  equations, rendered with smooth shading and stored as a watertight mesh;
- **cylinder** — circular rings at two heights plus a side surface and two caps,
  with explicit radius and height parameters.

In scope:

- surface mathematics for all three objects;
- a shared polygon-mesh representation with validation;
- polygon triangulation, outward face normals and an ASCII OBJ exporter;
- professional figure rendering (`axis equal`, lighting, smooth shading,
  labelled axes, multiple camera angles);
- unit tests and standalone demonstration scripts.

Out of scope (deliberately):

- 3D transformations and 4×4 matrices — Issue #008;
- projection and the full lighting model — Issues #009–#010;
- Unity scene construction, activities, TCP/IP and JSON — untouched;
- any modification of Issue #005/#006 files or existing tests.

The module is **additive**: no tracked file in the repository was modified.
`MATLAB/Tests/runAllTests.m` discovers the new test classes automatically, so it
did not need editing.

---

## 2. Mesh representation

All three primitives return the same plain struct, produced and validated by
`cmr.graphics.Mesh3D.create`:

| Field | Type | Meaning |
|---|---|---|
| `name` | string scalar | object name, e.g. `"cube"` |
| `vertices` | `N×3` double | one `[x y z]` point per row |
| `faces` | `1×F` cell | each cell is a row of 1-based vertex indices (a polygon) |
| `vertexCount` | double | `N` |
| `faceCount` | double | `F` |
| `color` | `1×3` double | RGB in `[0, 1]` |
| `parameters` | scalar struct | construction parameters plus analytical volume/area |

Design decisions:

- **Polygons, not triangles.** The cube keeps six genuine quads instead of twelve
  triangles, so the rendered cube shows its real edges and no triangulation
  diagonals. The sphere mixes pole triangles with latitude-band quads; the
  cylinder uses side quads plus two n-gon caps. `Mesh3D.triangulate` converts
  everything to a triangle fan only where a triangle consumer needs it.
- **Outward orientation.** Every face is listed counter-clockwise seen from
  outside the solid, so Newell normals in `Mesh3D.faceNormals` point outwards.
  This is asserted by tests for each object.
- **Base MATLAB only.** No toolbox, no third-party library, no Python.

### 2.1 Validation

`Mesh3D.create` rejects:

| Error identifier | Cause |
|---|---|
| `cmr:graphics:Mesh3D:invalidName` | empty name |
| `cmr:graphics:Mesh3D:invalidVertices` | fewer than 3 vertices, non-finite, or non-real coordinates |
| `cmr:graphics:Mesh3D:invalidFaces` / `invalidFace` | faces not index vectors, fewer than 3 corners, non-integer or non-finite indices |
| `cmr:graphics:Mesh3D:faceIndexOutOfRange` | index outside `1..N` |
| `cmr:graphics:Mesh3D:repeatedFaceVertex` | the same vertex twice in one face |
| `cmr:graphics:Mesh3D:invalidColor` | colour outside `[0, 1]` |
| `cmr:graphics:Mesh3D:invalidParameters` | parameters not a scalar struct |
| `cmr:graphics:Mesh3D:degenerateFace` | zero-length Newell normal (thrown by `faceNormals`) |
| `cmr:graphics:Mesh3D:invalidMesh` | helper called with a malformed struct |
| `cmr:graphics:Mesh3D:invalidFilePath` / `exportFailed` | bad OBJ destination or file cannot be opened |

---

## 3. Cube mathematics

A cube of side length `s` centred at `c = (cx, cy, cz)` has half-length
`h = s/2`. Its eight vertices are all sign combinations of `h`:

```
v1 (cx-h, cy-h, cz-h)    v2 (cx+h, cy-h, cz-h)
v3 (cx+h, cy+h, cz-h)    v4 (cx-h, cy+h, cz-h)
v5 (cx-h, cy-h, cz+h)    v6 (cx+h, cy-h, cz+h)
v7 (cx+h, cy+h, cz+h)    v8 (cx-h, cy+h, cz+h)
```

Faces, counter-clockwise from outside:

| Face | Indices | Normal | Side |
|---|---|---|---|
| bottom | `[1 4 3 2]` | `-z` | `z = cz - h` |
| top | `[5 6 7 8]` | `+z` | `z = cz + h` |
| front | `[1 2 6 5]` | `-y` | `y = cy - h` |
| right | `[2 3 7 6]` | `+x` | `x = cx + h` |
| back | `[3 4 8 7]` | `+y` | `y = cy + h` |
| left | `[4 1 5 8]` | `-x` | `x = cx - h` |

Analytical metadata: `volume = s³`, `surfaceArea = 6·s²`. Every edge has length
`s`; opposite faces are parallel and every pair of adjacent faces is
perpendicular. For the default demo cube (`s = 3`) the volume is `27` and the
surface area is `54`, both asserted numerically.

The demo renders the cube with `patch('Vertices', ..., 'Faces', <6×4 matrix>)`
so the six quads stay visible as quads.

---

## 4. Sphere mathematics

### 4.1 Parametric equations

With radius `r`, centre `c`, longitude `theta` and polar angle `phi`:

```
x(theta, phi) = cx + r · sin(phi) · cos(theta)
y(theta, phi) = cy + r · sin(phi) · sin(theta)
z(theta, phi) = cz + r · cos(phi)

theta ∈ [0, 2π]     phi ∈ [0, π]
```

`phi = 0` is the north pole `(cx, cy, cz + r)` and `phi = π` is the south pole
`(cx, cy, cz - r)`. Eliminating the angles gives the implicit form

```
(x - cx)² + (y - cy)² + (z - cz)² = r²
```

which is exactly what the tests check: every stored vertex satisfies
`|v - c| = r` to within `1e-12`.

### 4.2 Rendering grid

`Sphere3D.parameterValues(L, M)` returns `M+1` longitudes from `0` to `2π` and
`L+1` latitudes from `0` to `π`, endpoints included. `Sphere3D.coordinates`
returns `(L+1)×(M+1)` matrices ready for `surf`; the duplicated seam column and
pole rows are intentional, because that is what makes the rendered surface
close smoothly.

`Sphere3D.create` instead builds a mesh without duplicate vertices:

- 1 north-pole vertex, 1 south-pole vertex;
- `L-1` latitude rings of `M` vertices each;
- `M` pole triangles at each pole and `(L-2)·M` quads in between;
- total vertices `2 + (L-1)·M`, total faces `L·M`.

For `L = 40`, `M = 56` (the demo): `2186` vertices and `2240` faces.

Analytical metadata uses the exact sphere values `4πr³/3` and `4πr²`; the
polygonal mesh itself only approximates them, which is why the metadata is
labelled as analytical rather than recomputed from the polyhedron.

### 4.3 Smooth appearance

The demo draws the sphere with `surf(X, Y, Z, C)` where `C` is a truecolour
array of the object colour, plus `FaceColor = 'interp'`,
`FaceLighting = 'gouraud'` and `EdgeColor = 'none'`. The result is a smooth
shaded ball; no axes-wide `shading` call is used (see §8.3).

---

## 5. Cylinder mathematics

### 5.1 Surface equations

With radius `r`, height `h` and centre `c`, and
`theta_j = 2π(j-1)/N` for `j = 1..N`:

```
bottom_j = (cx + r cos(theta_j), cy + r sin(theta_j), cz - h/2)
top_j    = (cx + r cos(theta_j), cy + r sin(theta_j), cz + h/2)
```

- **side:** the quads between consecutive bottom/top vertices;
- **bottom cap:** the n-gon `[N, N-1, ..., 1]` (reversed so its normal is `-z`);
- **top cap:** the n-gon `[N+1, N+2, ..., 2N]` (normal `+z`).

The mesh stores `2N` vertices, `N` side quads and 2 caps, so `faceCount = N+2`
and the solid is closed. The seam is not duplicated: vertex `N` connects back to
vertex `1` through `mod`.

`Cylinder3D.sideGrid` returns a `2×(N+1)` grid (bottom row, top row, repeated
first column) for `surf`; `Cylinder3D.capCoordinates` returns the closed circle
`N+1` points for `fill3` caps. Both use the same angles as the mesh.

### 5.2 Metadata

For a polygonal approximation with `N` segments:

```
segment length  ℓ = 2r sin(π/N)
cap area        A = ½ N r² sin(2π/N)
volume          V = A · h
surface area    S = N · ℓ · h + 2A
```

`parameters` stores both these discrete values and the ideal circle values
`πr²h` and `2πrh + 2πr²`. As `N` grows, the discrete values converge to the
ideal ones; for `N = 4` the prism values are exact, and both facts are asserted
by tests. Demo values (`r = 1.2`, `h = 3`, `N = 48`): `96` vertices, `50` faces.

---

## 6. API reference

All methods are `static`; the classes are never instantiated.

### 6.1 `cmr.graphics.Cube3D`

| Method | Returns | Notes |
|---|---|---|
| `verticesAndFaces(sideLength, center)` | `[8×3, 1×6 cell]` | raw geometry, no mesh wrapper |
| `create(sideLength, center, color)` | mesh struct | validated; adds volume and surface area |

Defaults: `sideLength = 2`, `center = [0 0 0]`, `color = [0.20 0.55 0.90]`.

Errors: `cmr:graphics:Cube3D:invalidSideLength`, `invalidCenter`.

### 6.2 `cmr.graphics.Sphere3D`

| Method | Returns | Notes |
|---|---|---|
| `parameterValues(latitudeBands, longitudeBands)` | `[theta, phi]` | endpoint-inclusive rows |
| `coordinates(radius, center, latitudeBands, longitudeBands)` | `[X, Y, Z]` | `(L+1)×(M+1)` surf grid |
| `create(radius, center, latitudeBands, longitudeBands, color)` | mesh struct | watertight polygon mesh |

Defaults: `radius = 1`, `center = [0 0 0]`, `L = 36`, `M = 48`,
`color = [0.15 0.70 0.45]`. Minimum band counts: `L ≥ 2`, `M ≥ 3`.

Errors: `cmr:graphics:Sphere3D:invalidRadius`, `invalidCenter`,
`invalidLatitudeBands`, `invalidLongitudeBands`.

### 6.3 `cmr.graphics.Cylinder3D`

| Method | Returns | Notes |
|---|---|---|
| `parameterValues(radialSegments)` | `1×N theta` | excludes the duplicated seam |
| `sideGrid(radius, height, center, radialSegments)` | `[theta, X, Y, Z]` | `2×(N+1)` side grid |
| `capCoordinates(radius, center, radialSegments)` | `[X, Y]` | closed circle, `1×(N+1)` |
| `create(radius, height, center, radialSegments, color)` | mesh struct | closed solid with caps |

Defaults: `radius = 1`, `height = 2`, `center = [0 0 0]`, `N = 36`,
`color = [0.95 0.55 0.15]`. `N ≥ 3`.

Errors: `cmr:graphics:Cylinder3D:invalidRadius`, `invalidHeight`,
`invalidCenter`, `invalidRadialSegments`.

### 6.4 `cmr.graphics.Mesh3D`

| Method | Returns | Notes |
|---|---|---|
| `create(name, vertices, faces, color, parameters)` | mesh struct | validates and normalises every face to a row of `double` |
| `triangulate(mesh)` | `[T, sourceFace]` | fan triangulation; `k`-gon → `k-2` triangles |
| `faceNormals(mesh)` | `F×3` unit normals | Newell's method for planar and non-planar polygons |
| `bounds(mesh)` | `[minimum, maximum]` | axis-aligned bounding box |
| `exportOBJ(mesh, filePath)` | path string | triangulated ASCII OBJ; adds `.obj` and creates folders as needed |

The OBJ writer emits a comment header, `o <name>`, one `v` line per vertex and
one `f a b c` line per triangle. Indices are 1-based, matching the OBJ format,
and refer to the full vertex list.

---

## 7. Path setup and usage

`cmr.graphics` is a package, so MATLAB needs the folder that *contains* `+cmr`:

```matlab
addpath('D:/Matlab-Unity/MATLAB/Graphics');
```

or, for the whole project:

```matlab
addpath(genpath('D:/Matlab-Unity/MATLAB'));
```

Basic use:

```matlab
cube = cmr.graphics.Cube3D.create(3, [0 0 0], [0.20 0.52 0.90]);
sphere = cmr.graphics.Sphere3D.create(1.5, [0 0 0], 40, 56);
cylinder = cmr.graphics.Cylinder3D.create(1.2, 3, [0 0 0], 48);

cube.vertexCount      % 8
cube.faceCount        % 6
sphere.vertexCount    % 2186
sphere.faceCount      % 2240
cylinder.vertexCount  % 96
cylinder.faceCount    % 50

[X, Y, Z] = cmr.graphics.Sphere3D.coordinates(1.5, [0 0 0], 40, 56);
surf(X, Y, Z); axis equal; camlight headlight; lighting gouraud

cmr.graphics.Mesh3D.exportOBJ(cylinder, 'Shared_Data/Meshes/cylinder.obj');
```

Render a mesh with `patch`:

```matlab
patch('Vertices', cube.vertices, 'Faces', cell2mat(cube.faces), ...
    'FaceColor', cube.color, 'FaceLighting', 'flat');
axis equal; view(45, 25); camlight headlight; material dull
```

---

## 8. Demonstration scripts and figures

### 8.1 `demo3DObjects.m`

Run:

```matlab
cd('D:/Matlab-Unity/MATLAB/Graphics');
demo3DObjects
```

The script resolves the project root from `mfilename('fullpath')`, adds the
paths, builds the three objects from coordinates/equations, exports the OBJ
meshes and writes three figures. It accepts optional output folders:

```matlab
outputs = demo3DObjects();                       % default Deliverables + Shared_Data
outputs = demo3DObjects(screenshotFolder, meshFolder);
```

It prints the mesh summary, the exported file sizes, the analytical
verification values and the saved figure paths, and raises an error if a figure
was not written.

### 8.2 Figure 1 — shaded gallery

1×3 `tiledlayout`:

1. cube via `patch` with six quads, crisp edges, flat face lighting;
2. sphere via `surf` built from the parametric equations, `FaceColor` /
   `FaceLighting` interpolation for smooth shading;
3. cylinder side via `surf` plus two `fill3` caps, drawn with hold enabled so
   all three graphics objects survive.

Each tile has `axis equal`, `grid on`, `box on`, labelled `x/y/z` axes,
`view(45, 25)`, a headlight and a bold title stating the construction. A
super-title shows the sphere equations.

### 8.3 Figure 2 — four viewing angles

2×2 `tiledlayout` of the same scene (cube at `x = -4.5`, sphere at the origin,
cylinder at `x = +4.5`), shown from isometric `(45°, 25°)`, front `(0°, 0°)`,
side `(90°, 0°)` and top `(0°, 90°)`. `axis equal` and a common data box keep
all proportions identical across the views. The scene uses `hold on` and draws
the cube last so its flat faces are unaffected by the curved surfaces.

> **Implementation note.** High-level plotting functions (`fill3`, `plot3`) clear
> an axes whose `NextPlot` is `replace`. The cylinder caps originally deleted the
> side surface, and the wireframe markers deleted the meshes. The helpers now
> save `ishold`, switch `hold on`, and restore the previous state, which is why
> the demo is warning-free and shows complete objects. This was found by
> pixel-verifying the exported PNGs, not assumed from the code.

### 8.4 Figure 3 — mesh construction

1×3 panels showing the polygon structure:

- cube: wireframe quads plus all eight vertices as markers;
- sphere: latitude/longitude wireframe with both poles marked;
- cylinder: side wireframe plus both cap circles.

Each panel prints its vertex and face counts in the title.

### 8.5 Evidence

| File | Size (px) | Content |
|---|---|---|
| `Deliverables/Screenshots/Issue007_3D_Objects.png` | 2070 × 728 | shaded cube, sphere and cylinder with axes and titles |
| `Deliverables/Screenshots/Issue007_3D_Views.png` | 1647 × 1361 | the same scene from four camera angles |
| `Deliverables/Screenshots/Issue007_3D_Mesh_Structure.png` | 1960 × 691 | vertices, rings, bands, quads and caps |

Figures are visible in the MATLAB desktop and invisible under `matlab -batch`
(`usejava('desktop')`). In batch mode each figure is closed after export to
release graphics memory (see §10).

### 8.6 OBJ exports

| File | Vertices | Triangles | Size |
|---|---|---|---|
| `Shared_Data/Meshes/cube.obj` | 8 | 12 | 335 bytes |
| `Shared_Data/Meshes/sphere.obj` | 2186 | 4368 | 158043 bytes |
| `Shared_Data/Meshes/cylinder.obj` | 96 | 188 | 5076 bytes |

Every generated file was re-read and checked: the maximum face index is
`8 / 2186 / 96` respectively, so no face references a missing vertex.

---

## 9. Acceptance-criteria traceability

| Issue #007 requirement | Where it is satisfied |
|---|---|
| Cube from vertices and faces | `Cube3D.verticesAndFaces` / `create`; 8 vertices, 6 quads; `t3DObjects` checks counts, corners, edge lengths and normals |
| Cube patch rendering, colour, proportions | `demo3DObjects` figure 1; `axis equal`; bbox 422 × 449 px at the isometric view |
| Sphere from `(theta, phi)` equations | `Sphere3D.coordinates` / `create`; equations in §4 |
| Sphere renders smoothly | `surf` with interp colour and Gouraud lighting; figure 1 |
| Sphere vertices on the surface | `t3DObjects/sphereVerticesLieOnRadius` and `sphereCoordinatesSatisfyEquation` |
| Cylinder radius and height | `Cylinder3D.create` parameters and metadata; tests check bounds and radii |
| Circular cross-section | `theta_j` rings, `capCoordinates`; tests check all ring vertices |
| Side plus top/bottom caps | 48 side quads + 2 n-gon caps; tests check cap membership and outward normals |
| `axis equal`, labels, lighting, shading, titles, 3D view | `finishObjectAxes`, `styleSceneAxes`, `styleMeshAxes`; figures 1–3 |
| Clean visualization | titles, grid, box, headlight, dull material, consistent colours |
| Tests executed | 22 + 25 new tests pass; 190/190 full regression pass (see test report) |
| Mesh export without extra dependencies | `Mesh3D.exportOBJ`, base MATLAB only |

---

## 10. Limitations and notes

- **MATLAB R2025b is the project target but is NOT installed on this machine.**
  Everything was executed on R2026b (26.2.0.3386108), so R2025b compatibility is
  **NOT VERIFIED**. Only base MATLAB functions are used (`sin`, `cos`, `linspace`,
  `meshgrid`, `patch`, `surf`, `fill3`, `plot3`, `camlight`, `material`, `view`,
  `exportgraphics`). The newest functions used are `tiledlayout`/`nexttile`
  (R2019b) and `exportgraphics` (R2020a), both available in R2025b, so no
  incompatibility is expected.
- **Analytical vs discrete values.** `volume`/`surfaceArea` for the sphere and
  cylinder are the exact mathematical values; the tessellated mesh is only an
  approximation. `idealVolume`/`idealSurfaceArea` are provided alongside the
  discrete cylinder values for comparison.
- **No transformations, projection or full lighting model.** Objects are built
  in world coordinates and rendered with MATLAB's camera/lighting; 3D
  transformations and projection belong to later issues.
- **Not wired into the game or Unity.** This issue adds a geometry library,
  demos and evidence files only; it does not change the TCP/JSON protocol.
- **OBJ export is intentionally triangle-only.** Polygon faces are fan
  triangulated, which is the safest common denominator for Unity import. No
  normals or texture coordinates are written.
- **Memory pressure during development.** The development machine had about
  0.8 GB free of 7.5 GB RAM while a MATLAB desktop session was open. One
  `exportgraphics` call failed transiently and the JVM logged "out of memory".
  The demo now retries an export once and closes each figure after export in
  `-batch` mode; subsequent complete runs succeeded with no warnings. This is an
  environment limitation, not a geometry defect.
