# EduBot ROS 2 core — FLEET image (self-contained, reproducible).
#
# Bakes the workspace in at build time from a manifest staged by CI as
# .build.repos (edubot.repos for :dev, edubot.lock.repos for :stable/:vX.Y.Z).
# Build context is the repo root. The developer counterpart that builds at
# runtime from bind-mounted src is docker/ros2.dev.Dockerfile.
FROM ros:humble-ros-base

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-rviz2 \
    ros-humble-joint-state-publisher-gui \
    ros-humble-xacro \
    ros-humble-robot-state-publisher \
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
    git build-essential wget v4l-utils \
 && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir -U vcstool
# Runtime Python deps.
#  - pyserial/numpy: edubot_hardware talks to the ESP32 via pyserial.
#  - adafruit-circuitpython-neopixel-spi: corner status LEDs (led_node). Driven
#    over SPI (not PIO) so it works on the Raspberry Pi 5 / Ubuntu 24.04; needs
#    'dtparam=spi=on' on the host and /dev mapped into the (privileged) container.
#  - adafruit-circuitpython-bno08x: BNO085 IMU node (imu_node). Needs I2C
#    enabled on the host ('dtparam=i2c_arm=on') and /dev/i2c-1 accessible.
RUN pip3 install --no-cache-dir pyserial numpy lgpio adafruit-circuitpython-neopixel-spi adafruit-circuitpython-bno08x

WORKDIR /edubot_ws

# Staged by CI: cp <chosen manifest> .build.repos before docker build.
COPY .build.repos ./workspace.repos
RUN mkdir -p src && vcs import src < workspace.repos

RUN . /opt/ros/humble/setup.sh && colcon build

RUN echo "source /opt/ros/humble/setup.bash" >> /root/.bashrc && \
    echo "if [ -f /edubot_ws/install/setup.bash ]; then source /edubot_ws/install/setup.bash; fi" >> /root/.bashrc

COPY docker/run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
