# CLEAN MY ROOM!

## Project Overview
Clean My Room is a 3D educational game for children developed using MATLAB R2025b and Unity.

The game teaches children through three interactive activities:
1. Color Sorting.
2. Taste Sorting.
3. Number and Dot Matching.

The player explores a 3D bedroom, completes the activities using the keyboard and mouse, earns three stars, and receives an encouraging message from the father character after completing all activities.

## Technologies
- **MATLAB R2025b:** Computer Graphics, 2D and 3D transformations, projection, lighting calculations, geometric computations, activity validation, and game logic.
- **Unity:** 3D Environment, Characters, Animations, UI, Audio, Player Movement, and User Interaction.
- **TCP/IP and JSON:** Communication between MATLAB and Unity.

Python is not used in this project.

## Project Structure
- **MATLAB:** Computational algorithms, graphics processing, and game logic.
- **Unity:** Interactive 3D game, environment, characters, and user interface.
- **Shared_Data:** Shared resources and communication specifications.
- **Documentation:** Technical documentation and test results.
- **Deliverables:** MATLAB graphics demonstrations, screenshots, videos, and final reports.

## Main Activities
- **Color Sorting:** Match objects to their corresponding colored baskets.
- **Taste Sorting:** Classify food into Sweet, Sour, Bitter, and Salty categories.
- **Number and Dot Matching:** Match numbers from 1 to 10 with groups containing the same number of dots.

Each completed activity awards one star. The player must collect all three stars to finish the game.

## Input
The player uses the keyboard and mouse only.

- **Keyboard:** Move the player and interact with activity stations.
- **Mouse:** Select, drag, and release objects inside activities.

Camera input, webcam access, hand tracking, and gesture recognition are not used.

## System Architecture
The project uses a MATLAB–Unity architecture with an approximate responsibility distribution of 70% MATLAB and 30% Unity.

**MATLAB** is responsible for computational processing, Computer Graphics algorithms, mathematical and geometric calculations, activity logic, answer validation, scoring, and game progress.

**Unity** is responsible for displaying the 3D environment, player interactions, characters, animations, user interface, and visual feedback. It sends player interaction requests to MATLAB and displays the results received from it.

MATLAB is responsible for determining whether an activity answer is correct and whether the activity is completed.

The two applications communicate through TCP/IP using JSON messages. MATLAB acts as the TCP server, while Unity acts as the TCP client.

## Game Flow
1. The player explores the bedroom.
2. The player completes the Color Sorting activity and earns the first star.
3. The player completes the Taste Sorting activity and earns the second star.
4. The player completes the Number and Dot Matching activity and earns the third star.
5. After collecting all three stars, the father character appears and congratulates the player.
6. The game reaches its completed state.

## Project Goal
Develop a complete and interactive 3D educational game for children while demonstrating Computer Graphics concepts through MATLAB-based algorithms and integrating them with a Unity 3D environment.