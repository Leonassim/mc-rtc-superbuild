# # Requiered Ceres-Solver: http://ceres-solver.org/installation.html
# # Tutorial
# wget http://ceres-solver.org/ceres-solver-2.2.0.tar.gz
# # CMake
# sudo apt-get install cmake
# # google-glog + gflags
# sudo apt-get install libgoogle-glog-dev libgflags-dev
# # Use ATLAS for BLAS & LAPACK
# sudo apt-get install libatlas-base-dev
# # Eigen3
# sudo apt-get install libeigen3-dev
# # SuiteSparse (optional)
# sudo apt-get install libsuitesparse-dev
# tar zxf ceres-solver-2.2.0.tar.gz
# mkdir ceres-bin
# cd ceres-bin
# cmake ../ceres-solver-2.2.0
# make -j3
# make test
# make install

AddProject(mc_force_sensor_calibration_controller 
  GITHUB jrl-umi3218/mc_force_sensor_calibration_controller
  GIT_TAG origin/master
  DEPENDS mc_rtc
)
