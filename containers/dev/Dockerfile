FROM ros:humble-ros-base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    openssl \
    python3-numpy \
    python3-onnx \
    python3-opencv \
    python3-colcon-common-extensions \
    python3-pip \
    ros-humble-cv-bridge \
    ros-humble-image-transport \
    ros-humble-rmw-cyclonedds-cpp \
    vim \
    wget \
    docker.io \
    docker-compose \
 && rm -rf /var/lib/apt/lists/*

RUN echo "source /opt/ros/humble/setup.bash" >> /root/.bashrc && \
    echo "if [ -f /workspace/install/setup.bash ]; then source /workspace/install/setup.bash; fi" >> /root/.bashrc

RUN curl -fsSL https://code-server.dev/install.sh | sh

COPY workspace.repos /opt/workspace.repos
RUN pip3 install -U vcstool && \
    vcs import /opt < /opt/workspace.repos

COPY start-code-server.sh /usr/local/bin/start-code-server.sh
RUN chmod +x /usr/local/bin/start-code-server.sh

WORKDIR /workspace

EXPOSE 8443

CMD ["/usr/local/bin/start-code-server.sh"]
