# Edubot Robot Skill

This dashboard skill describes the safe robot actions available to the Vibe Coding assistant.

## Available motion

- The robot accepts velocity commands on `/cmd_vel`.
- Message type: `geometry_msgs/msg/Twist`.
- Hardware drive: four-wheel mecanum/omni platform.
- Wheel/protocol order in the hardware node: RR, FR, RL, FL.
- Kinematic defaults from `edubot_bringup/bringup.launch.py`:
  - wheel radius: `0.04 m`
  - half length: `0.095 m`
  - half width: `0.1025 m`
  - encoder ticks per wheel revolution: `4320`
  - `/cmd_vel` timeout: `0.5 s`
- ESP32 motor firmware clamps wheel speed at `11.5 rad/s`.
- Derived theoretical pure translation limit: about `0.46 m/s`.
- Nav2 local planner limits are `vx=0.45 m/s`, `vy=0.45 m/s`, `wz=1.9 rad/s`.
- Vibe Coding command limits default to `0.45 m/s` linear, `1.9 rad/s` angular, and up to `30 s` per primitive.
- Linear axes:
  - `linear.x`: forward/backward in meters per second.
  - `linear.y`: left/right strafe in meters per second.
  - `linear.z`: not used.
- Angular axes:
  - `angular.z`: yaw rotation in radians per second.
  - `angular.x` and `angular.y`: not used.
- Prefer `move_distance` for natural distance requests:
  - "fahre 1 m nach vorne" -> `distance_x_meters=1.0`, `distance_y_meters=0.0`
  - "fahre 10 cm rueckwaerts" -> `distance_x_meters=-0.1`, `distance_y_meters=0.0`
  - "fahre 1 m nach links" -> `distance_x_meters=0.0`, `distance_y_meters=1.0`
  - "fahre 1 m nach rechts" -> `distance_x_meters=0.0`, `distance_y_meters=-1.0`
- Prefer `rotate_angle` for angle requests:
  - "drehe dich um 180 Grad" -> `angle_degrees=180`
  - "200 Grad im Uhrzeigersinn" -> `angle_degrees=200`, `clockwise=true`
- Prefer `run_motion_sequence` for multi-step requests:
  - "erst 2 m vor, dann 2 m links, dann 90 Grad drehen" -> move, move, rotate.
- Prefer `drive_arc` for curve/bogen requests.
- For a 10 cm forward move, use `move_distance` with `distance_x_meters=0.1`, not raw duration guesses.
- Because the hardware node stops after `0.5 s` without fresh `/cmd_vel`, movements longer than `0.5 s` must publish repeatedly. The `drive` tool handles this.

## Tool policy

- Use `move_distance` for all distance-based natural language movement commands.
- Use `rotate_angle` for all angle-based rotation commands.
- Use `drive_arc` for curve or bogen commands.
- Use `run_motion_sequence` for ordered multi-step commands.
- Use `drive` only for explicit velocity-for-duration commands.
- Use `stop` when the child asks to stop, pause, wait, cancel, or when a command is ambiguous.
- Use `list_ros_topics` when the child asks what the robot can see or which ROS2 topics are available.
- Use `publish_cmd_vel` only for explicit `/cmd_vel` Twist-style commands.
- Use `publish_ros_topic`, `ros_topic_info`, `ros_topic_echo`, and `ros_topic_hz` for ROS2 topic publish/info/echo/hz requests.
- Do not claim that the robot moved if a tool returns an error.
- Do not reject normal requests like 1 m forward/left/right if they fit within the command limits; translate them to the right movement primitive.
- Ask a short follow-up question only if the requested behavior needs sensors or actuators that are not listed here or if direction/distance is truly ambiguous.

## Useful ROS2 terminal equivalents

These examples are context only. The assistant should call tools rather than run terminal commands directly.

```bash
ros2 topic list -t
ros2 topic pub -r 10 /cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0.2, y: 0.0, z: 0.0}, angular: {x: 0.0, y: 0.0, z: 0.0}}"
ros2 topic pub --once /cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0.0, y: 0.0, z: 0.0}, angular: {x: 0.0, y: 0.0, z: 0.0}}"
```
