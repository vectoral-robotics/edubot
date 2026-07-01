FROM ros:humble-ros-base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    curl \
    gnupg \
    python3-colcon-common-extensions \
    python3-pip \
    ros-humble-ament-cmake \
    ros-humble-nav2-rviz-plugins \
    ros-humble-rviz2 \
    ros-humble-xacro \
    xvfb \
    xauth \
    xserver-xorg-video-dummy \
    xserver-xorg-core \
    libgl1-mesa-dri \
    libgles2-mesa \
    mesa-utils \
    openbox \
 && rm -rf /var/lib/apt/lists/*

# RPi 5: try V3D GPU via /dev/dri first, fall back to llvmpipe software rendering.
# Driver selection happens at runtime in start-xpra.sh based on architecture.
# LP_NUM_THREADS: llvmpipe render threads (2 is good balance for RPi 5's 4 cores)
ENV LP_NUM_THREADS=2 \
    MESA_GL_VERSION_OVERRIDE=3.3

# Install a newer XPRA from upstream repo for better HTML5 auto-resize.
RUN install -d /etc/apt/keyrings && \
    curl -fsSL https://xpra.org/gpg.asc | gpg --dearmor -o /etc/apt/keyrings/xpra.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/xpra.gpg] https://xpra.org/ jammy main" > /etc/apt/sources.list.d/xpra.list && \
    apt-get update && apt-get install -y xpra && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/edubot_rviz_ws
COPY containers/rviz/workspace.repos ./workspace.repos
RUN pip3 install -U vcstool && \
    mkdir -p src && \
    vcs import src < workspace.repos
RUN . /opt/ros/humble/setup.sh && \
    colcon build --symlink-install --packages-select edubot_description edubot_viz

COPY containers/rviz/start-xpra.sh containers/rviz/start-rviz.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start-xpra.sh /usr/local/bin/start-rviz.sh

EXPOSE 14500

CMD ["/usr/local/bin/start-xpra.sh"]
