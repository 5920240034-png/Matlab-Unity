# Issue #007 — Test Report

**3D Geometric Objects: Cube, Sphere and Cylinder**

| Field | Value |
|---|---|
| Issue | #007 |
| Branch | `feature/issue-007-graphics` |
| Date of final verification | 2026-11-17 |
| MATLAB used | **R2026b (26.2.0.3386108)**, PCWIN64 |
| R2025b status | **NOT VERIFIED** — R2025b is not installed on the development machine |
| Test runner | `MATLAB/Tests/runAllTests.m` (unchanged) |
| New tests | **47** (`tMesh3D` 22 + `t3DObjects` 25) |
| Full regression on this branch | **94 / 94 tests passed, 0 failed, 0 incomplete** |
| Evidence | `Deliverables/Screenshots/Issue007_*.png` (3 files) + `Shared_Data/Meshes/*.obj` (3 files) |

> **Version caveat.** `AGENTS.md` §14.1 names MATLAB R2025b as the project target. Every result
> below was produced on R2026b, the only MATLAB installation available on this machine. R2025b
> compatibility is therefore **untested**, not "passing".
>
> **Branch scope caveat.** The earlier "190 / 190" figure in this report included the three
> Issue #006 2D test classes (`tCohenSutherland`, `tGraphics2D`, `tTransform2D` — 96 tests).
> Those files live on `feature/issue-006-graphics` and are not present on this branch. The
> full suite available on `feature/issue-007-graphics` is 94 tests, and all 94 pass.

---

## 1. Commands executed

### 1.1 Mesh suite alone

```powershell
& "D:\stage3\bin\matlab.exe" -batch "cd('D:/Matlab-Unity/MATLAB/Tests'); r = runtests('tMesh3D'); assertSuccess(r); fprintf('RESULT %d/%d passed\n', sum([r.Passed]), numel(r));"
```

```
RESULT 22/22 passed
```

### 1.2 Primitive suite alone

```powershell
& "D:\stage3\bin\matlab.exe" -batch "cd('D:/Matlab-Unity/MATLAB/Tests'); r = runtests('t3DObjects'); assertSuccess(r); fprintf('RESULT %d/%d passed\n', sum([r.Passed]), numel(r));"
```

```
RESULT 25/25 passed
```

### 1.3 Full regression suite (this branch)

```powershell
& "D:\stage3\bin\matlab.exe" -batch "cd('D:/Matlab-Unity/MATLAB/Tests'); runAllTests"
```

```
=== MATLAB TEST SUMMARY ===
Total      : 94
Passed     : 94
Failed     : 0
Incomplete : 0
Duration   : 35.44 s
===========================
```

Per class (from the same run):

| Test class | Tests | Passed | Duration |
|---|---|---|---|
| `t3DObjects` | 25 | 25 | 5.02 s |
| `tCodec` | 18 | 18 | 3.01 s |
| `tMesh3D` | 22 | 22 | 2.74 s |
| `tServerIntegration` | 17 | 17 | 23.30 s |
| `tSession` | 8 | 8 | 0.84 s |
| `tValidator` | 4 | 4 | 0.54 s |
| **Total** | **94** | **94** | **35.44 s** |

`47 pre-existing (18 + 17 + 8 + 4) + 22 + 25 = 94`. No pre-existing test was modified, skipped or
removed, and `runAllTests.m` was not changed — it discovers the new classes automatically.

The previously reported **190 / 190** run was performed on a tree that also contained the three
Issue #006 2D test classes (`tCohenSutherland` 28, `tGraphics2D` 44, `tTransform2D` 24 = 96 tests).
Those files exist on `feature/issue-006-graphics`, not on this branch: `94 + 96 = 190`. The 190
result is therefore **not a result obtained on `feature/issue-007-graphics`** and must not be
cited as such.

---

## 2. `tMesh3D` — 22 tests, all passed

| # | Test | Verifies |
|---|---|---|
| 1 | `createAcceptsNumericFaceMatrix` | numeric face matrix is normalised into a cell array; name, counts, colour preserved |
| 2 | `createAcceptsMixedCellFaces` | mixed quad + triangle faces are accepted |
| 3 | `createPreservesParameters` | construction parameters survive validation |
| 4 | `createRejectsTooFewVertices` | fewer than 3 vertices → `invalidVertices` |
| 5 | `createRejectsNonFiniteVertices` | `NaN` coordinate → `invalidVertices` |
| 6 | `createRejectsEmptyName` | empty name → `invalidName` |
| 7 | `createRejectsInvalidColor` | colour > 1 → `invalidColor`; wrong length → MATLAB size error |
| 8 | `createRejectsNonStructParameters` | numeric parameters → `invalidParameters` |
| 9 | `createRejectsOutOfRangeFaceIndex` | index 4 of 3 and index 0 → `faceIndexOutOfRange` |
| 10 | `createRejectsTooShortFace` | 2-corner matrix and 2-corner cell → `invalidFaces` / `invalidFace` |
| 11 | `createRejectsRepeatedFaceVertex` | repeated index in one face → `repeatedFaceVertex` |
| 12 | `createConvertsRowFaceInput` | a single row face becomes one face |
| 13 | `triangulateQuadReturnsTwoTriangles` | quad → `[1 2 3; 1 3 4]`, source map `[1;1]` |
| 14 | `triangulateMixedFacesUsesFanOrder` | triangle + pentagon fan order and source mapping |
| 15 | `triangulateRejectsMalformedMesh` | empty faces struct → `invalidMesh` |
| 16 | `boundsReturnsAxisAlignedBox` | `[0 0 0]`–`[2 2 0]` for the test square |
| 17 | `faceNormalsOfSquarePointAlongPositiveZ` | single square normal is exactly `[0 0 1]` |
| 18 | `faceNormalsRejectDegenerateFace` | collinear face → `degenerateFace` |
| 19 | `exportOBJWritesVerticesAndTriangles` | cube OBJ: 8 `v` lines, 12 `f` lines, `o cube`, header comment |
| 20 | `exportOBJAddsMissingExtension` | `.obj` appended, file exists |
| 21 | `exportOBJCreatesMissingFolder` | nested output folder created |
| 22 | `exportOBJRejectsInvalidDestination` | numeric and empty destination → `invalidFilePath` |

---

## 3. `t3DObjects` — 25 tests, all passed

### 3.1 Cube (6 tests)

| # | Test | Verifies |
|---|---|---|
| 1 | `cubeHasEightVerticesAndSixFaces` | 8 vertices, 6 faces, `8×3` vertices, `1×6` faces |
| 2 | `cubeVerticesAreExpectedCorners` | every corner equals `center ± side/2` |
| 3 | `cubeFacesAreQuadsWithOutwardNormals` | all faces have 4 corners; normals point away from centre and are axis-aligned |
| 4 | `cubeEdgesHaveSideLength` | exactly 12 unique edges, each of length `sideLength` |
| 5 | `cubeMetadataMatchesGeometry` | `volume = 27`, `surfaceArea = 54`, bbox `3×3×3` for `s = 3` |
| 6 | `cubeRejectsInvalidInputs` | zero/NaN side, 2-element or NaN centre, bad colour |

### 3.2 Sphere (8 tests)

| # | Test | Verifies |
|---|---|---|
| 7 | `sphereParameterRange` | `theta` 0…2π (`M+1`), `phi` 0…π (`L+1`), uniform spacing |
| 8 | `sphereGridSizeAndSeam` | `(L+1)×(M+1)` grids; seam columns equal; north-pole row is `(cx, cy, cz+r)` |
| 9 | `sphereCoordinatesSatisfyEquation` | all grid points satisfy `(x−cx)² + (y−cy)² + (z−cz)² = r²` |
| 10 | `sphereMeshCounts` | `2+(L−1)M` vertices, `LM` faces, `2M` pole triangles, `(L−2)M` quads |
| 11 | `sphereVerticesLieOnRadius` | every stored vertex is exactly `r` from the centre; one north and one south pole |
| 12 | `sphereFacesPointOutward` | unit normals; every normal has positive dot product with its radial direction |
| 13 | `sphereMetadataMatchesAnalyticalValues` | `V = 4πr³/3`, `S = 4πr²` |
| 14 | `sphereRejectsInvalidInputs` | zero radius, bad centre, too few bands, non-integer bands |

### 3.3 Cylinder (10 tests)

| # | Test | Verifies |
|---|---|---|
| 15 | `cylinderParameterValues` | `N` distinct angles, uniform spacing, no duplicated seam |
| 16 | `cylinderVertexAndFaceCounts` | `2N` vertices, `N+2` faces, `N` quads and two `N`-gon caps |
| 17 | `cylinderRadiusHeightAndCentre` | every vertex at radius `r`; `N` vertices at each cap height; total height exactly `h` |
| 18 | `cylinderCapsUseEveryRingVertex` | bottom cap uses 1…N reversed, top cap uses N+1…2N |
| 19 | `cylinderFacesPointOutward` | side normals point radially outwards; caps are exactly `−z` and `+z` |
| 20 | `cylinderSideGridMatchesMesh` | `surf` grid rows equal the stored rings; seam column repeated |
| 21 | `cylinderCapCoordinatesAreClosedCircles` | `N+1` points, closed, all at radius `r` |
| 22 | `cylinderMetadataApproachesCircle` | relative volume/area error < `1e-4` at `N = 720` |
| 23 | `cylinderMetadataIsExactForSquarePrism` | discrete formulas exact at `N = 4` |
| 24 | `cylinderRejectsInvalidInputs` | zero radius/height, bad centre, `<3` or fractional segments |
| 25 | `allPrimitiveMeshesTriangulateWithoutDegenerateFaces` | cube, sphere and cylinder triangulate to finite in-range indices |

---

## 4. Demonstration run

The final verification used the documented alternate output-directory form of the demo so that
the 15 delivered files were not overwritten:

```powershell
& "D:\stage3\bin\matlab.exe" -batch "cd('D:/Matlab-Unity/MATLAB/Graphics'); out='C:/Users/zhraa mohsin/AppData/Local/Temp/opencode/issue007-verify/screenshots'; msh='C:/Users/zhraa mohsin/AppData/Local/Temp/opencode/issue007-verify/meshes'; demo3DObjects(out, msh);"
```

Final output (complete, no warnings, exit code 0):

```
Clean My Room - Issue #007 3D geometric objects
MATLAB 26.2.0.3386108 (R2026b) on PCWIN64

Generated meshes:
  cube     :    8 vertices,    6 faces, bounds [-1.50 -1.50 -1.50] to [1.50 1.50 1.50]
  sphere   : 2186 vertices, 2240 faces, bounds [-1.50 -1.50 -1.50] to [1.50 1.50 1.50]
  cylinder :   96 vertices,   50 faces, bounds [-1.20 -1.20 -1.50] to [1.20 1.20 1.50]

Exported OBJ meshes:
  C:\Users\zhraa mohsin\AppData\Local\Temp\opencode\issue007-verify\meshes\cube.obj (335 bytes)
  C:\Users\zhraa mohsin\AppData\Local\Temp\opencode\issue007-verify\meshes\sphere.obj (158043 bytes)
  C:\Users\zhraa mohsin\AppData\Local\Temp\opencode\issue007-verify\meshes\cylinder.obj (5076 bytes)
Saved C:\Users\zhraa mohsin\AppData\Local\Temp\opencode\issue007-verify\screenshots\Issue007_3D_Objects.png (160679 bytes)
Saved C:\Users\zhraa mohsin\AppData\Local\Temp\opencode\issue007-verify\screenshots\Issue007_3D_Views.png (154123 bytes)
Saved C:\Users\zhraa mohsin\AppData\Local\Temp\opencode\issue007-verify\screenshots\Issue007_3D_Mesh_Structure.png (172640 bytes)

Mesh verification:
  cube     : 8 vertices, 6 faces, volume = 27.0000, surface = 54.0000
  sphere   : 2186 vertices, 2240 faces, radius = 1.5000
  cylinder : 96 vertices, 50 faces, radius = 1.2000, height = 3.0000
  cube bounds: [-1.50 -1.50 -1.50] to [1.50 1.50 1.50]

Saved 3 evidence figures:
  C:\Users\zhraa mohsin\AppData\Local\Temp\opencode\issue007-verify\screenshots\Issue007_3D_Objects.png
  C:\Users\zhraa mohsin\AppData\Local\Temp\opencode\issue007-verify\screenshots\Issue007_3D_Views.png
  C:\Users\zhraa mohsin\AppData\Local\Temp\opencode\issue007-verify\screenshots\Issue007_3D_Mesh_Structure.png
```

The three OBJs from this run are byte-for-byte identical (SHA-256) to the delivered files in
`Shared_Data/Meshes/`. The three PNGs have identical byte sizes and are pixel-identical to the
delivered files in `Deliverables/Screenshots/`. The delivered files were not modified.

### 4.1 OBJ file verification (re-read from disk)

| File | Vertices | Triangles | Max face index | Valid |
|---|---|---|---|---|
| `cube.obj` | 8 | 12 | 8 | yes |
| `sphere.obj` | 2186 | 4368 | 2186 | yes |
| `cylinder.obj` | 96 | 188 | 96 | yes |

Expected triangle counts: cube `6 quads × 2 = 12`; sphere `2×56 pole + 38×56×2 = 4368`;
cylinder `48×2 side + 2×46 cap = 188`. All face indices are in range and every face is a triangle.
The delivered OBJ files and the freshly exported ones have identical SHA-256 hashes.

### 4.2 PNG content verification

**Human visual inspection was not performed.** The agent cannot view images directly, so the
exported files were analysed numerically (`imread` + HSV masks per tile). Every tile of every
figure contains rendered content:

| Figure | Pixels | Bytes | Non-white | Per-panel ink |
|---|---|---|---|---|
| `Issue007_3D_Objects.png` | 2070 × 728 | 160679 | 22.0 % | 24.7 / 20.2 / 21.2 % |
| `Issue007_3D_Views.png` | 1647 × 1361 | 154123 | 18.6 % | 20.7 / 16.3 / 24.2 / 13.3 % |
| `Issue007_3D_Mesh_Structure.png` | **2070 × 728** | **172640** | 9.7 % | 8.6 / 12.1 / 8.3 % |

The `Issue007_3D_Mesh_Structure.png` dimensions and byte size above replace the stale
`1960 × 691` / `152228 bytes` figures previously recorded here. The ink percentages come from
the earlier numeric analysis and were not recomputed; the final verification confirmed the file
is pixel-identical to a fresh demo export.

For figure 2 the panels are read row-wise: isometric, front, side, top. Every panel contains
non-zero blue, green and orange masks (for example the isometric panel has 36 145 blue,
25 498 green and 30 659 orange pixels), so no object is missing from any view.

Object silhouettes in the gallery figure, measured from colour masks:

| Object | Bounding box | Aspect | Fill of bbox | Interpretation |
|---|---|---|---|---|
| cube (blue) | 422 × 449 px | 0.94 | 0.52 | hexagon-like isometric silhouette |
| sphere (green) | 296 × 297 px | **1.00** | **0.79** | circle; `π/4 ≈ 0.785` for a filled disc |
| cylinder (orange) | 239 × 370 px | 0.65 | 0.94 | height 3 vs width 2.4 at 25° elevation |

All three colour masks contain tens of thousands of pixels in figure 1, and all three objects
appear again in all four panels of figure 2.

---

## 5. Defects found and fixed during verification

### 5.1 Cylinder side and wireframes were being erased (fixed)

**Symptom:** pixel analysis of the first PNG showed the orange mask as a single 239 × 101
ellipse — the top cap only. The cylinder side and bottom cap were absent.

**Cause:** `surf` was followed by high-level `fill3` calls while the axes had
`NextPlot = 'replace'`. Each high-level call clears the axes, so the second `cap` call left only
the top cap. The same pattern affected `plot3` after `surf`/`patch` in the wireframe panels, and
the sphere wireframe showed only its markers.

**Fix:** each multi-object helper (`drawCylinder`, `drawCubeWireframe`, `drawSphereWireframe`,
`drawCylinderWireframe`) now saves `ishold`, enables `hold on`, and restores the previous state.
After the fix the cylinder mask measures 239 × 370 px (aspect 0.65, fill 0.94) — a complete
upright cylinder — and the mesh-structure PNG grew from 92 815 to 152 228 bytes as the side
wireframe returned (a historical figure; the current delivered file is 172 640 bytes, see §4.2).

**Regression evidence:** the demo was rerun after the fix; the final verification run is described
in §4.

### 5.2 Transient `exportgraphics` failure under memory pressure (mitigated)

One run failed while exporting the third figure (`Failed to export`), and a later run emitted
repeated "Out of memory" warnings before the batch process was terminated. The machine has
7.5 GB RAM with roughly 0.8 GB free while a MATLAB desktop session is open; the JVM crash log
recorded `Native memory allocation (mmap) failed`. This is an environment limitation, not a
geometry or export-format error — earlier and later runs exported the same figure successfully.

**Mitigation:** in `-batch` mode each figure is closed immediately after export, export resolution
is 130 dpi, and one retry follows a `drawnow` if `exportgraphics` throws. A genuine repeated
failure still rethrows the original error. The two complete runs after the mitigation produced all
three PNGs with no warnings.

### 5.3 Patch colour-array warnings from axes-wide shading (fixed)

**Symptom:** `Error creating or updating Patch ... FaceVertexCData ... Number of colours must
equal number of vertices` while rendering the cylinder.

**Cause:** an axes-wide `shading(ax, 'interp')` was applied after both `surf` and `fill3`
graphics existed. The caps created by `fill3` carry a single face colour, which is incompatible
with interpolated per-vertex shading.

**Fix:** the axes-wide `shading` calls were removed. The smooth objects already request
interpolation on their own handles (`FaceColor = 'interp'`, `FaceLighting = 'gouraud'`), while the
caps and cube stay flat-shaded. The final run is warning-free.

---

## 6. Warnings and errors

| Run | Warnings | Errors | Result |
|---|---|---|---|
| `tMesh3D` | none | none | 22/22 passed |
| `t3DObjects` | none | none | 25/25 passed |
| `runAllTests` | none | none | 94/94 passed on this branch |
| `demo3DObjects` (final) | none | none | 3 PNG + 3 OBJ written |

Earlier development runs did emit patch `FaceVertexCData` warnings and one `exportgraphics`
failure; both causes are described in §5 and are resolved or mitigated. No warning is hidden in
this report.

---

## 7. Git state

The Issue #007 change set consists of exactly the 15 files listed below. On this branch no Issue
#006 or #005 file, README, AGENTS.md, test runner, protocol or Unity file was created or modified;
`git diff` for tracked files is empty. `cmr.graphics` previously contained only `Transform2D.m`
and `CohenSutherland.m`; the four new classes are additions inside the existing package folder.

```
Documentation/Graphics/3D_Geometric_Objects.md
Documentation/Testing/Issue007_Test_Report.md
Deliverables/Screenshots/Issue007_3D_Mesh_Structure.png
Deliverables/Screenshots/Issue007_3D_Objects.png
Deliverables/Screenshots/Issue007_3D_Views.png
MATLAB/Graphics/+cmr/+graphics/Cube3D.m
MATLAB/Graphics/+cmr/+graphics/Cylinder3D.m
MATLAB/Graphics/+cmr/+graphics/Mesh3D.m
MATLAB/Graphics/+cmr/+graphics/Sphere3D.m
MATLAB/Graphics/demo3DObjects.m
MATLAB/Tests/t3DObjects.m
MATLAB/Tests/tMesh3D.m
Shared_Data/Meshes/cube.obj
Shared_Data/Meshes/cylinder.obj
Shared_Data/Meshes/sphere.obj
```

---

## 8. Manual verification steps

1. **Run the new suites**

   ```powershell
   & "D:\stage3\bin\matlab.exe" -batch "cd('D:/Matlab-Unity/MATLAB/Tests'); assertSuccess(runtests('tMesh3D'))"
   & "D:\stage3\bin\matlab.exe" -batch "cd('D:/Matlab-Unity/MATLAB/Tests'); assertSuccess(runtests('t3DObjects'))"
   ```

   Expect 22 and 25 passed respectively.

2. **Run the full regression suite**

   ```powershell
   & "D:\stage3\bin\matlab.exe" -batch "cd('D:/Matlab-Unity/MATLAB/Tests'); runAllTests"
   ```

   Expect `Total 94 | Passed 94 | Failed 0 | Incomplete 0` on `feature/issue-007-graphics`.
   A 190-test total belongs to a tree that also contains the Issue #006 2D test classes.

3. **Regenerate the evidence**

   ```matlab
   cd('D:/Matlab-Unity/MATLAB/Graphics')
   demo3DObjects
   ```

   In the desktop, three figure windows open; under `matlab -batch` only the PNGs and OBJs are
   written. `demo3DObjects(outputDirectory, meshDirectory)` writes the evidence elsewhere; the
   final verification used that form so the delivered files were not overwritten.

4. **Human visual inspection of the PNGs** in `Deliverables/Screenshots/` — **NOT DONE** by the
   agent; owner review is requested. Expected content:

   - figure 1: blue cube with six quads and crisp edges, smooth green sphere, orange cylinder
     with visible side and both caps, labelled axes, grid, lighting;
   - figure 2: the same three objects from isometric, front, side and top views, all with
     `axis equal` and unchanged proportions;
   - figure 3: cube corners/edges, sphere latitude–longitude wireframe with both poles marked,
     cylinder side wireframe plus both cap circles.

5. **Spot-check the API**

   ```matlab
   addpath('D:/Matlab-Unity/MATLAB/Graphics');
   cube = cmr.graphics.Cube3D.create(3);            % 8 vertices, 6 faces
   sphere = cmr.graphics.Sphere3D.create(1.5);      % 2186 vertices, 2240 faces
   cylinder = cmr.graphics.Cylinder3D.create(1.2, 3); % 96 vertices, 50 faces
   [X, Y, Z] = cmr.graphics.Sphere3D.coordinates(1.5, [0 0 0], 40, 56);
   max(abs(sqrt(X.^2 + Y.^2 + Z.^2) - 1.5), [], 'all')   % ≈ 0
   ```

6. **Import an OBJ** into Unity or a mesh viewer and confirm it appears as a closed solid.

---

## 9. Items not run / outstanding

| Item | Status | Reason |
|---|---|---|
| MATLAB R2025b test run | **NOT RUN** | R2025b not installed; only R2026b was tested |
| Human visual inspection of the three PNGs | **NOT DONE** | Not performed by the agent; numeric analysis and pixel comparison only. Owner review requested. |
| Full 190-test suite (incl. Issue #006 tests) | **NOT RUN on this branch** | Three 2D test classes live on `feature/issue-006-graphics`; 94 tests are available here |
| Unity import of the OBJ files | **NOT RUN** | Unity-side work is out of scope for Issue #007 |
| MATLAB↔Unity protocol tests | Not applicable | MATLAB-only geometry module; the pre-existing `tServerIntegration` (17 tests) still passes |
| Git commit / push | Owner-authorised | On `feature/issue-007-graphics` only; no merge into `main` |
