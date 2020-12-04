CHECK_DIR=/gpfs/dell2/emc/retros/noscrub/Dingchen.Hou/GIT/GEFS
WORK_DIR=/gpfs/dell6/emc/modeling/noscrub/Dingchen.Hou/GEFS/ThHd
#Before Start, make sure you have checked out the tag in right place and decided where to work
cd $CHECK_DIR/rocoto
compile_install_all.sh -r yes
cd $CHECK_DIR/pqpf

mkdir -p $WORK_DIR
cd $WORK_DIR
ln -s $CHECK_DIR GEFS

ln -s GEFS/exec exec
ln -s GEFS/parm parm
ln -s GEFS/sorc sorc
ln -s GEFS/ush ush
ln -s GEFS/util util
ln -s GEFS/versions versions

cp -pr GEFS/rocoto rocoto
cp -pr GEFS/pqpf/user_full.conf rocoto
mkdir jobs scripts
cp -pr GEFS/pqpf/J* jobs
cp -pr GEFS/pqpf/ex* scripts

cd rocoto
compile_install_all.sh -r yes
cp -pr ../GEFS/pqpf/enspost_hr.ent tasks
cd ..

compile_install_all.sh -b yes

#You should be at $WORK_DIR/rocoto. If not, it went wrong somewhere 
