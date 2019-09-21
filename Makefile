# If you want to rebuild all images, set this to --no-cache from the commandline
DOCKER_ARGS?=

# You need to specify a particular target
#--------------------------------------------------------------------------
# Stable and local targets

.PHONY: gz9_kinetic
gz9_kinetic:
	docker build ${DOCKER_ARGS} -t gz9_kinetic gz9_kinetic

.PHONY: gz9_dashing
gz9_crystal: ubuntu_18
	docker build ${DOCKER_ARGS} -t gz9_crystal gz9_crystal

.PHONY: gz9_ros2
gz9_ros2: ubuntu_18
	docker build ${DOCKER_ARGS} --build-arg ros2=$(VERSION) -t gz9_ros2 gz9_ros2

.PHONY: ubuntu_18
ubuntu_18:
	docker build ${DOCKER_ARGS} -t ubuntu_18 ubuntu_18
