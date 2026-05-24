#$ delay 75
podman run -it --name=ac3_container docker.io/library/fedora:43 /bin/bash

#$ expect \]#
dnf install 'dnf-command(copr)'

#$ expect Is this ok \[y/N\]:
#$ wait 750
y

#$ expect \]#
dnf copr enable jdxcode/mise -y

#$ expect \]#
#$ wait 500
#$ send dnf install gcc gcc-c++ glibc-devel glibc-static libstdc++ libstdc++-devel libstdc++-static 
#$ wait 100
#$ send  \
#$ sendcontrol m
#$ sendcontrol i
#$ send m4 git zlib-devel graphviz mise -y
#$ sendcontrol m

#$ expect \]#
#$ wait 1000
useradd -m build

#$ expect \]#
#$ wait 80
#$ send exec su -l build
#$ sendcontrol m

#$ expect \]\$
#$ wait 500
clear
#$ wait 100
git clone https://git.verticordia.com/pellegrini/AC3-TP1.git --branch=v0.1.1

#$ expect \]\$
#$ wait 1500
#$ send cd AC3
#$ sendcontrol i
#$ expect TP1
#$ sendcontrol m

#$ expect \]\$
#$ wait 100
mise trust

#$ expect \]\$
#$ wait 100
mise run
#$ expect confirm
#$ wait 750
#$ send simul
#$ wait 50
#$ sendcontrol m

#$ expect \]\$
#$ wait 10000
clear

#$ expect \]\$
#$ wait 1000
mise run
#$ expect confirm
#$ wait 750
#$ send report
#$ wait 50
#$ sendcontrol m

#$ expect \]\$
#$ wait 2000
#$ send stat rep
#$ sendcontrol i
#$ send /main.pdf
#$ sendcontrol m

#$ expect \]\$
#$ wait 4500
#$ send exit
#$ sendcontrol m

#$ wait 80
clear
#$ wait 80
#$ send cd report/
#$ sendcontrol m
#$ wait 80
podman cp ac3_container:/home/build/AC3-TP1/report/main.pdf ./
just release
sha256sum A_*.pdf | cut -f1 -d' '

#$ wait 15000
#$ sendcontrol d
