FROM ros:humble-ros-base

RUN apt-get update && apt-get install -y \
    git \
    python3-colcon-common-extensions \
    ros-humble-async-web-server-cpp \
    ros-humble-cv-bridge \
    ros-humble-image-transport \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    libboost-all-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/ws

RUN mkdir -p /opt/ws/src && \
    cd /opt/ws/src && \
    git clone https://github.com/RobotWebTools/web_video_server.git && \
    cd /opt/ws/src/web_video_server && \
    git checkout ros2

RUN . /opt/ros/humble/setup.sh && \
    colcon build

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
