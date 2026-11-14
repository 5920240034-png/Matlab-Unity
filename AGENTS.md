# AGENTS.md
# CLEAN MY ROOM - PROJECT RULES

## 1. Project Identity

Project Name: Clean My Room

Project Type:
3D Educational Game for Children.

Technologies:
- MATLAB R2025b
- Unity
- C#
- TCP/IP
- JSON

Python is strictly prohibited.
Do not introduce Python scripts, packages, or dependencies.

## 2. Main Project Goal

Develop a complete 3D educational game for children.

Story:

A father asks his child to clean and organize their bedroom.

The child enters the bedroom and finds three interactive tasks:

1. Bed - Color Sorting.
2. Dining Table - Taste Classification.
3. Study Desk - Mathematics Activity.

Each activity has a floating star.

The child must complete all three activities to collect three stars.

After collecting all stars, the father appears, congratulates the child, and the game ends.

Do not change the agreed game story or activity structure without explicit approval.

## 3. MATLAB Requirement - CRITICAL

MATLAB must contribute approximately 70% of the project's computational and algorithmic implementation, subject to the agreed academic assessment criteria.

MATLAB is the primary computational and mathematical processing side.

MATLAB must implement:

- 2D Computer Graphics algorithms.
- 3D Geometry Generation.
- 3D Geometric Transformations.
- Translation.
- Rotation.
- Scaling.
- Graphics and projection calculations.
- Lighting and shading calculations.
- Activity-space coordinate mapping.
- Mouse-to-activity coordinate conversion.
- Drop-target hit testing.
- Object placement and snap-position calculations.
- Activity layout generation.
- Color activity validation.
- Taste activity validation.
- Mathematics activity validation.
- Hint and scoring logic.
- Difficulty management.
- Activity completion logic.
- Game progress and star calculation.

Do not move these computational responsibilities into Unity C#.

The 70/30 target refers to computational and algorithmic responsibilities, not simply source-code line counts.

Document the actual distribution of responsibilities to support the academic assessment.

## 4. Unity Responsibilities

Unity must implement:

- 3D Bedroom Environment.
- Player Character.
- Father Character.
- Player Movement.
- Keyboard and Mouse Input Collection.
- Furniture and Props.
- Interactive Objects.
- UI.
- Animations.
- Audio.
- Scene Management.
- Visual Feedback.
- Display of MATLAB-generated results.
- TCP Client Communication.

Unity collects user input and sends relevant activity requests to MATLAB.

Unity displays the results returned by MATLAB.

Unity must not independently decide whether an educational answer is correct.

## 5. Input and Interaction

Keyboard and Mouse are the only approved input methods for this project.

### Keyboard

- Move the player character.
- Interact with an activity station.
- Navigate the game when required.

### Mouse

- Select objects.
- Drag and drop objects inside activities.
- Confirm or cancel actions when required.

### MATLAB Processing

Unity captures mouse and keyboard input.

For activity interactions:

1. Unity captures the input.
2. Unity converts the relevant screen coordinates into request data.
3. Unity sends a placement request to MATLAB.
4. MATLAB performs coordinate mapping, hit testing, and validation.
5. MATLAB returns the result.
6. Unity displays the returned result.

MATLAB remains responsible for educational validation.

### Permanently Excluded Features

The following features are NOT part of this project:

- Camera integration.
- Webcam integration.
- Hand tracking.
- Hand detection.
- Gesture recognition.
- Pinch detection.
- Hand-pose models.
- Hand calibration.
- Camera preview.
- Webcam support packages.
- Camera-dependent interaction.

Do not implement, install, or reintroduce any of these features unless the project owner explicitly changes this decision.

This restriction applies to all current and future Issues, implementation plans, documentation, and AI agents.

## 6. Communication

MATLAB is the computational TCP Server.

Unity is the TCP Client.

Communication:
- TCP/IP.
- JSON.
- UTF-8.
- Newline-delimited messages.

Initial configuration:

IP: 127.0.0.1

Port: 55001

Both applications initially run on the same Windows computer.

All messages must be documented.

Use unique request IDs for activity operations.

The protocol should support the following operations:

- PLACE_REQ: Unity requests an object placement operation.
- PLACE_RES: MATLAB returns the placement and validation result.

Additional message types may be introduced only when justified by a separate communication requirement.

Handle:
- Invalid messages.
- Invalid JSON.
- Partial TCP messages.
- Multiple messages received together.
- Connection failures.
- Disconnections.
- Reconnection.
- Timeouts.
- Resource cleanup.

Unity may start without MATLAB.

While disconnected, Unity must:

- Display a clear connection status.
- Retry the connection automatically.
- Disable activities that require MATLAB processing.
- Never validate answers locally.
- Never complete activities locally.

Restore normal functionality after reconnection.

Do not introduce camera or hand-tracking message types.

Keep MATLAB and Unity message structures consistent.

## 7. Graphics Requirements

Both 2D and 3D Computer Graphics are required.

MATLAB must generate and demonstrate computational graphics algorithms.

Required responsibilities include:

- 2D Basic Drawing Algorithms.
- 2D Geometric Transformations.
- Clipping.
- 3D Geometric Objects.
- 3D Transformations.
- Projection and relevant graphics calculations.

Unity is responsible for presenting the final 3D game environment.

Do not replace MATLAB graphics tasks with Unity primitives or ready-made graphics implementations.

Standalone MATLAB demonstration scripts must be provided where required by the relevant Issues.

Save graphics evidence, test figures, and demonstration materials inside:

Deliverables/

## 8. Development Rules

Before changing files:

- Inspect the existing repository.
- Read README.md.
- Read this AGENTS.md.
- Check existing implementations.
- Check relevant GitHub Issue requirements.
- Avoid duplicate scripts and classes.
- Preserve existing working functionality.

Work on one GitHub Issue at a time.

Follow the Issue Acceptance Criteria.

Do not implement future phases without approval.

When an older Issue conflicts with these permanent project decisions:

- Preserve its valid objectives.
- Exclude camera and hand-tracking requirements.
- Adapt the implementation to Keyboard and Mouse.
- Explain any necessary changes before implementation.

Do not silently invent new requirements.

## 9. Code Quality

- Use clear naming.
- Add useful comments.
- Separate responsibilities.
- Avoid unnecessary dependencies.
- Avoid hardcoded file paths.
- Handle errors.
- Keep MATLAB and Unity communication interfaces consistent.
- Use reusable functions and components.
- Maintain compatibility with MATLAB R2025b.
- Avoid duplicate implementations.

## 10. Testing Rules

Every implemented feature must include a test plan.

Never claim a test passed unless it was actually executed.

If MATLAB or Unity cannot be launched:

- Explain why.
- Provide manual testing steps.
- Mark the test as NOT RUN.

Do not hide warnings or errors.

Test MATLAB functionality independently where possible.

Test MATLAB-Unity communication independently from the game activities.

Verify that Unity correctly handles MATLAB disconnection and reconnection.

## 11. Git Rules - STRICT

The project owner is responsible for ALL Git operations.

AI agents must NEVER:

- Stage files.
- Commit changes.
- Push changes.
- Merge branches.
- Create branches.
- Switch branches.
- Delete branches.
- Reset branches.
- Rebase branches.
- Perform destructive Git operations.
- Modify Git history.

Do not execute Git write operations under any circumstances.

AI agents may inspect Git status, branches, and diffs using read-only commands.

Never overwrite another team member's work.

Never commit secrets, API keys, or credentials.

After implementation, leave all changes in the working directory for the project owner to review.

## 12. AI Working Method

For every Issue:

1. Inspect the repository.
2. Read AGENTS.md and README.md.
3. Review the Issue requirements.
4. Check compatibility with permanent project decisions.
5. Explain the implementation plan.
6. List files to create or modify.
7. Identify dependencies.
8. Implement only the approved Issue scope.
9. Run available tests.
10. Fix implementation errors.
11. Report files changed.
12. Report tests passed and not run.
13. Provide manual verification instructions.
14. Identify unresolved issues.
15. Wait for human approval before closing the Issue.

Do not assume that approval for one Issue authorizes implementation of another.

## 13. Important Restrictions

- No Python.
- No camera or webcam.
- No hand tracking.
- No gesture recognition.
- No pinch detection.
- No hand calibration.
- No unnecessary external packages.
- No fake test results.
- No duplicate projects.
- No moving MATLAB computational responsibilities into Unity.
- No changing the agreed game story without approval.
- No deleting or replacing existing assets without approval.
- No Git write operations.
- No implementing future Issues without approval.

## 14. Project-Wide Permanent Decisions

These decisions apply to every Issue and every AI agent working on this project:

1. MATLAB R2025b is the target MATLAB version.
2. MATLAB handles approximately 70% of computational and algorithmic responsibilities.
3. Unity handles approximately 30% of visualization and interaction responsibilities.
4. Keyboard and Mouse are the only approved input methods.
5. Camera and hand-tracking functionality are permanently excluded unless explicitly reapproved by the project owner.
6. MATLAB is responsible for educational activity validation.
7. Unity must not independently validate educational answers.
8. MATLAB and Unity communicate using TCP/IP and JSON.
9. All standalone graphics evidence belongs in Deliverables/.
10. The project owner performs all Git operations.

When uncertain about a requirement, stop and ask the project owner instead of making assumptions.