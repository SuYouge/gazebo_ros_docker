# ROS开发环境容器化

[原文地址](http://mecha-su.cn/2020/06/29/docker-4/)

主要流程如下：

1. 安装主机Docker环境
2. 编译DockerFile，处理网络问题
3. 初始化容器并补充必要的环境
4. 导出容器为镜像并重新构建容器
5. VScode关联容器环境

用到的DockerFile和容器启动脚本来自github上的项目[gazebo_ros_docker](https://github.com/eborghi10/gazebo_ros_docker)。下面详细说明步骤。

## 1. 主机Docker环境配置

主机Docker环境配置主要包括如下步骤：

1. 脚本安装docker
2. 修改Docker默认存储位置

### 1.1 脚本安装docker-ce

```bash
curl -sSL https://get.docker.com/ | sh
```

如果没有网络问题应该可以直接完成布置，按照提示将用户加入相应的用户组即可（可能需要重新登录）。

### 1.2 修改Docker默认存储位置

可以参考[这篇文章](https://zhuanlan.zhihu.com/p/95533274)。

编辑`/etc/docker/daemon.json `（如果没有则新建）为：

```json
{
  "registry-mirrors": ["http://hub-mirror.c.163.com"], // 顺便指定镜像源
  "data-root": "/path/to/docker-repo" // 
}
```

至此主机Docker环境配置完成。

## 2. 编译Dockerfile

脚本来自github上的项目[gazebo_ros_docker](https://github.com/eborghi10/gazebo_ros_docker)。

```bash
./build --gazebo 9 # 如果没有网络问题直接运行即可
```

在实际编译过程中主要遇到以下两个问题：

1. `ros-*-ros-control`这个依赖识别错误为gazebo-11版本，按照需求本应是gazebo-9
2. `sudo rosdep init`和`rosdep update`日常出错

解决办法就是先把基础镜像构建出来，初始化一个容器后再在上面进行补全。为了方便直接注释掉`ros1/Dockerfile`中以下几句：

```dockerfile
COPY packages.txt packages.txt  # 这句注意保留不要注释
# RUN apt-get update && \
#    xargs -a packages.txt apt-get install -y

# RUN rosdep init
# RUN rosdep update
```

构建可以得到基础镜像，通过运行`./run`直接构造初始化容器。

## 3. 开发环境补全

这一步的主要任务是解决**步骤2**中出现的两个问题。

在初始化容器中默认的登录目录在`catkin_ws`下，需要向上跳转到有`packages.txt`的位置下，并运行：

```bash
sudo apt-get update && xargs -a packages.txt apt-get install -y
```

这样所有的依赖都可以安装好。如果依然提示`gazebo-11`相关信息，可以注释掉`packages.txt`中的`ros-*-ros-control`包名，再次运行上述指令后手动补充这个依赖，即：

```bash
sudo apt-get install ros-melodic-ros-control
```

然后是`rosdep`的初始化问题：

方便的（我唯一的）解决方法是使用代理，至少可以解决`sudo rosdep init`的问题（也可以手动下载这个文件到某个位置）。至于`rosdep update`超时的问题，我在代理的基础上按照[这篇文章](https://blog.csdn.net/qq_43310597/article/details/106034812)进行了设置，目前效果很好屡试不爽。

Docker环境的代理通过SSR设置局域网共享进行，这样在Docker容器内进行`export http_proxy`等操作和主机终端进行的操作就一样了。

## 4. 容器导出

接下来为了方便每次调用这个修改好的镜像，对其进行固化。

主要有两种思路，将容器`commit`或者将容器`export`。下面实现`export`这种方案。

主要就两个命令：

```bash
docker export $container_id > 容器快照名
docker import 镜像名称:版本号
```

这样就可以把一个修改号的容器导出为镜像并导入其他docker环境了。

为了方便从新的镜像中构建容器，我们需要对`run`脚本进行一些修改：

```python
# 将
dockerfile  = '{}'.format('ros1' if ros2 == '' else 'ros2')
# 修改为
dockerfile  = '{}'.format('docker-image-name' if ros2 == '' else 'ros2')
# 其中 docker-image-name 就是你所定义的新的镜像名
```

至此ROS开发环境的容器化就基本完成。除了上述主要内容外还有以下两点补充。

`./run -ws workspace`：`-ws`参数可以挂载主机上的工作环境到容器环境。

还有一个问题就是如何通过VSCode来得到容器内的开发环境，实现自动补全，定义跳转等功能。

## 5. VSCode-Container

关键在于一个名为`remote-containers`的vscode插件，利用它可以通过vscode启动容器并对其中的内容进行跳转。具体的细节可以参考[这个链接](https://github.com/ms-iot/vscode-ros/issues/156)以及我修改后的[gazebo_ros_docker]()项目。

将`.devcontainer`和`.vscode`复制到你想要打开的工作空间下就可以在vscode内通过左下角的`Open a remote window`按钮，选择`Open folder in container`即可跳转到容器内部。

如果修改了镜像的名字，则可以通过`Dockerfile`来进行调整，`devcontainer.json`利用一些标签代替了相应的docker命令。

# Dockers: ROS + Gazebo

## Available Dockers

- ROS 1 (Melodic release only) + Gazebo 9
- ROS 2 + Gazebo 9

## Generate docker image

```bash
./build
```

### Optional arguments

- [`-r1`|`--ros1`]: select ROS 1 version (`melodic`). Enabled by default.
- [`-r2`|`--ros2`]: select ROS 2 version.
- [`-g`|`--gazebo`]: select Gazebo version. Only Gazebo 9 is supported for ROS 2.

### Examples

ROS 1 Melodic + Gazebo 11

```bash
./build --gazebo 11
```

ROS 2 Eloquent + Gazebo 9

```bash
./build --ros2 eloquent
```

## Run docker image

```bash
./run
```

### Optional arguments

- [`-r1`|`--ros1`]: select ROS 1 version (`melodic`). Enabled by default.
- [`-r2`|`--ros2`]: select ROS 2 version.
- [`-c`|`--cmd`]: run command (default is `bash`). `tmux` can be used too.
- [`-ws`|`--workspace`]: select workspace to be mounted from the host.

**Note:** You don't need to specify the Gazebo version.

### Examples

ROS 1 Melodic + Gazebo 11

```bash
./run --cmd tmux
```

ROS 2 Eloquent + Gazebo 9

```bash
./run --ros2 eloquent -ws "/home/my_user/my_colcon_ws"
```

### IMPORTANT

- You need to have installed `nvidia-docker2` in your machine in order to make it work **ONLY** if you have an Nvidia GPU.
