# Autonomous Mobile Lego® Robot for iOS

This app demonstrates creating an autonomous mobile robot using a LiDAR capable iPad or iPhone with a Lego® Mindstorms Robot Inventor or Spike Prime.

## Safety

This software is currently undergoing experimental research and development. Some things may not work as expected, or may fail to work at all.

Children, animals and other vulnerable items should be removed from the surrounds to avoid potential collisions.

## How it works

The app makes use of LiDAR and ARKit on a capable iOS device, to produce a 3D mesh of its surroundings. 

The 3D mesh is converted into a 2D map which is used to compute a path from the robot's location to a waypoint, while avoiding colliding with obstacles on the way.

The robot attempts to move along the computed path through the physical world until it reaches the waypoint.

The robot works best in environments that are static with no moving obstacles, or obstacles that move only rarely or slowly. 

## Practical Application

### Overview

1. Build the robot and mount the iOS device.
2. Connect the device to the Lego® programmable hub.
3. Scan the environment to create a map.
4. Place a virtual waypoint.
5. Place the robot on the floor in a location where it can reach the waypoint.
6. Enable the robot and watch it go!

Details of each step are provided below.

### Step 1: Connect to the Hub

Before you begin, make sure your Lego® hub is paired with your iOS device and that you are able to connect to and control your robot from the Lego® app (Mindstorms or Spike Prime).  If you cannot control the robot from the Lego® app it is unlikely that this app will work with the robot.

1. Make sure the Lego® hub is paired with the iOS device. It should be listed under the _Bluetooth_ section in the _Settings_ app on iOS.  
3. Turn on the hub.
3. Wait for the hub to initialize, then press the Bluetooth button. The hub should start beeping and the button should start flashing blue.
4. Launch the app.
5. Press the _Disconnected_ button. The connection window should appear.
6. After some time (usually less than a minute), the Lego® hub should appear in the connection window.
7. Tap on the name of the hub in the connection window.
8. Once connected, the hub should play a tune and the _Disconnected_ button in the app should change to _Connected_.

If during usage the hub becomes disconnected, the button in the app will change to _Disconnected_. Tap the button to try re-establish the connection.

### Step 2: Scan the Surroundings

The LiDAR sensor on the iOS device is used to create a virtual map of the environment. The map is used to compute a path through the environment to a virtual waypoint.

The map should be created _before_ the robot can attempt to start navigating.

The goal is to create a 3D mesh that accurately represents the physical world. This is done by move the device capturing all of the surfaces in the surroundings.  

Scanning is performed in a similar same manner to many other LiDAR apps. Move through the environment while holding the iOS device, and possibly also the robot if the device is not detachable. 

Scan progress can be estimated by viewing the 3D view that is displayed on the screen. Coloured areas show areas that have been scanned, while black holes indicate areas that still need to be scanned. 

A top-down view of the map is displayed in the bottom-right view. Note any areas that do not correspond with the physical environment, such as holes or other missing features. These areas may need to be scanned multiple times to capture sufficient detail.

### Step 3: Place the Waypoint

Point the iOS device at the intended destination for the robot. Tap on the screen to place the waypoint, indicated as a purple box.

The robot may not be able to reach a waypoint placed too close to an obstacle. A distance of one meter (three feet) or more is often sufficient.

### Step 4: Place the Robot

Position the robot on the ground some distance away from the waypoint. 

The robot uses it's estimated elevation to estimate the ground plane. The waypoint needs to be placed on the same ground plane as the robot. The robot may fail to compute a path to the waypoint the waypoint is positioned too high or too low.

The robot enforces a minimum distance around obstacles to avoid collisions. It may fail to find a path where there is insufficient distance between obstacles, such as narrow passages or doorways, or places with tight corners. The intended pathway should be at least a meter wide.  

Verify that the robot has found a path by observing the gray line from the robot's current position to the waypoint position.  

### Step 5: Go!

When you are ready, tap the _Enable Robot_ button. The robot will immediately begin moving towards the waypoint. The robot should stop when it is within 500mm of the waypoint.

## Robot Design Tips

TODO

## Troubleshooting

__Hub turns off or disconnects__
The Lego® hub will occasionally turn itself off. This mostly happens if the hub is left for a period of inactivity. This also occurs occasionally with normal activity. The current solution is to turn the hub back on, quit and relaunch the app, and re-establish the connection to the hub.

__LiDAR tracking__
The standard advice for LiDAR apps is also applicable to this app. 

- Move slowly. Any sudden jerking or shaking motions can negatively affect ARKit's ability to track the movement or orientation of the device, leading to inaccurate measurements. This is often observed as features that are misplaced relative to each other.
- Make sure the environment is adequately lit. Daylight works best. Dim or artificial lighting may nagatively affect tracking.
- Relective or shiny surfaces can produce inaccurate results. Remove or cover such surfaces, or avoid pointing the LiDAR at them. Examples of problematic surfaces include: mirror, microwave oven, plastic bottle, etc.
- ARKit may be unable to track plain or featureless surfaces, such as a blank wall.

__No path to waypoint__
The robot may fail to find a path on the map even where one exists in the physical world. 

This may be due to insufficient detail captured through scanning, or it may be a result of inaccurate tracking leading to deformations in the map. These two issues can often be resolved by re-scanning the affected area, reducing interference, or improving lighting.

The robot may also fail to find a path trhough a region if there is insufficient  space between obstacles. Ensure there is at least one meter or more of open space between obstacles.

## Code

TODO: Document architecture

## Future 

Sundry list of ideas for further experimentation.

- Render the heightmap in hardware (instead of using the Field / Blob software renderer).
- Use planes detected by ARKit for producing the occupancy grid. Note that planes may extend through and under obstacles so this may require additional online obstacle avoidance measures.
- Use ARFrame depth buffer for obstacle detection and avoidence while moving. 
- Use front-facing camera for depth while using rear-facing camera for world tracking, on lower-end devices (iPhoneX).
- Use image recognition for estimating location. Use depth map only for collision avoidance.

## License

This project is licensed under the MIT license. See the LICENSE file for details. The LICENSE must be included and displayed in any product that includes this code in whole or in part.

## Limitation of liability

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

