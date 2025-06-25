ARG ROS_DISTRO=humble
FROM ros:${ROS_DISTRO}-ros-core-jammy

# Set non-interactive frontend for package installs
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies, build tools, and Gazebo Fortress with dev libraries
RUN apt-get update && apt-get install -y \
    # Basic tools
    wget curl unzip git \
    # For adding OSRF repository
    gnupg lsb-release \
    # Build essentials
    build-essential \
    # Mesa for rendering
    mesa-utils \
    # ROS 2 build and dependency tools
    python3-colcon-common-extensions \
    python3-rosdep \
    && \
    # Add the OSRF repository for Gazebo
    curl -sSL https://packages.osrfoundation.org/gazebo.key | gpg --dearmor -o /usr/share/keyrings/osrf-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null && \
    # Update sources again after adding new repo
    apt-get update && \
    # Install Gazebo Fortress (now named gz-fortress) and its development libraries
    # libgz-sim6-dev is the key package that provides headers for compiling against Fortress
    apt-get install -y \
      gz-fortress \
      libgz-sim6-dev \
    && \
    # Install ROS 2 packages for Gazebo integration
    # ros-gz-sim is the newer package name for the simulator integration
    apt-get install -y \
      ros-${ROS_DISTRO}-ros-gz-sim \
      ros-${ROS_DISTRO}-ros-gz-bridge \
      ros-${ROS_DISTRO}-ros-gz-interfaces \
      ros-${ROS_DISTRO}-tf2-tools \
    && \
    # Clean up apt cache to reduce image size
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Initialize and update rosdep
RUN rosdep init && rosdep update

# Create the workspace and download Gazebo models
RUN mkdir -p /ros2_ws/src && \
    curl -L https://github.com/osrf/gazebo_models/archive/refs/heads/master.zip -o /tmp/gazebo_models.zip && \
    unzip /tmp/gazebo_models.zip -d /tmp && \
    mkdir -p /root/.gazebo/models/ && \
    mv /tmp/gazebo_models-master/* /root/.gazebo/models/ && \
    rm -rf /tmp/gazebo_models.zip /tmp/gazebo_models-master

WORKDIR /ros2_ws

# --- IMPORTANT ---
# This section assumes you will be adding your source code to /ros2_ws/src
# For example, using a COPY instruction or a volume mount.
# COPY . /ros2_ws/src

# This build command is now more robust. It's often better to run this
# when you launch the container or in a later build stage,
# rather than in the base image Dockerfile itself, unless the source code is static.
RUN apt-get update && \
    /bin/bash -c 'source /opt/ros/${ROS_DISTRO}/setup.bash && \
                  rosdep install --from-paths src --ignore-src -r -y --rosdistro ${ROS_DISTRO} && \
                  colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release' && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set the entrypoint to source everything automatically
CMD ["/bin/bash", "-c", "source /opt/ros/${ROS_DISTRO}/setup.bash && source /ros2_ws/install/setup.bash && ros2 launch sjtu_drone_bringup sjtu_drone_bringup.launch.py"]
