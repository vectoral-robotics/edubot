# EduBot ROS 2 core — DEVELOPER image.
#
# Unlike the fleet image, this does NOT bake the workspace in. The source is
# bind-mounted from the host (./src -> /workspace/src) and colcon builds at
# container start, so whatever branch/commit you have checked out per repo is
# what runs. See docker/ros2-entrypoint.dev.sh.
FROM ros:humble-ros-base

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-rviz2 \
    ros-humble-joint-state-publisher-gui \
    ros-humble-xacro \
    ros-humble-robot-state-publisher \
    ros-humble-robot-localization \
    ros-humble-navigation2 \
    ros-humble-nav2-bringup \
    ros-humble-v4l2-camera \
    ros-humble-teleop-twist-keyboard \
    ros-humble-teleop-twist-joy \
    ros-humble-image-tools \
    ros-humble-rosbridge-server \
    ros-humble-cv-bridge \
    ros-humble-rmw-cyclonedds-cpp \
    python3-colcon-common-extensions \
    python3-flask \
    python3-opencv \
    python3-pip \
    git vim build-essential wget v4l-utils \
 && rm -rf /var/lib/apt/lists/*

# Runtime Python deps (see ros2.Dockerfile for details):
#  pyserial/numpy for the ESP32 bridge, adafruit neopixel-spi for the corner LEDs,
#  adafruit-circuitpython-bno08x for the BNO085 IMU node.
RUN pip3 install --no-cache-dir pyserial numpy lgpio adafruit-circuitpython-neopixel-spi adafruit-circuitpython-bno08x

RUN echo "source /opt/ros/humble/setup.bash" >> /root/.bashrc && \
    echo "if [ -f /workspace/install/setup.bash ]; then source /workspace/install/setup.bash; fi" >> /root/.bashrc

WORKDIR /workspace
# run.sh is the shared production launcher; the dev entrypoint builds from src
# then hands off to it (see ros2-entrypoint.dev.sh).
COPY run.sh /run.sh
COPY ros2-entrypoint.dev.sh /ros2-entrypoint.dev.sh
RUN chmod +x /run.sh /ros2-entrypoint.dev.sh

ENTRYPOINT ["/ros2-entrypoint.dev.sh"]
