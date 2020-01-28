#!/bin/bash -l

set -e

GMX=gmx_2019.4

PDB=${1}
METHOD=${2}

BASE_DIR=`pwd`
MARTINI_DIR=../martini
MARTINI_EXE=$MARTINI_DIR/martinize.py/martinize.py
MDP=$MARTINI_DIR/mdps
DSSP=$MARTINI_DIR/dssp/dssp


# All the preparation steps
python $MARTINI_EXE -f $BASE_DIR/$PDB -o system.top -x cg_sys.pdb -dssp $DSSP -p backbone -ff $METHOD

# Copy and editing the Force Field Files for including in the topology
cp $MARTINI_DIR/martini_v2.2.itp martini.itp
cp $MARTINI_DIR/martini_v2.0_ions.itp .

sed -i '/#include "martini.itp/a #include "martini_v2.0_ions.itp"' system.top

$GMX editconf -f cg_sys.pdb -d 1.2 -bt triclinic -o cg_sys.gro

# Minization in Vaccum
$GMX grompp -f $MDP/em.mdp -c cg_sys.gro -p system.top -o em-vac.tpr

$GMX mdrun -deffnm em-vac -v


# Solvate the system
$GMX solvate -cp em-vac.gro -cs $MARTINI_DIR/water.gro -radius 0.21 -o solvated.gro

# Fix the number of water in the topology
nb1=($(sed -n 2p cg_sys.gro))
nb2=($(sed -n 2p solvated.gro))

water=$((nb2 - nb1))
echo $water
cp system.top system.bak
echo -e "\nW         ${water}" >> system.top

# Add ions
$GMX grompp -f $MDP/em.mdp -c solvated.gro -p system.top -o ions.tpr

echo W | $GMX genion -s ions.tpr -o solvated_ions.gro -p system.top -neutral -pname NA -nname CL

# Minization in Solvent
$GMX grompp -f $MDP/em.mdp -c solvated_ions.gro -p system.top -o em-sol.tpr

$GMX mdrun -deffnm em-sol -v


# Fully restrained NPT at 2fs
$GMX grompp -f $MDP/npt_2fs.mdp -c em-sol.gro -r em-sol.gro -p system.top -o npt_2fs.tpr -maxwarn 1

$GMX mdrun -deffnm npt_2fs -v

# Fully restrained NPT at 10fs
$GMX grompp -f $MDP/npt_10fs.mdp -c npt_2fs.gro -r npt_2fs.gro -p system.top -o npt_10fs.tpr -t npt_2fs.cpt -maxwarn 1

$GMX mdrun -deffnm npt_10fs -v

# Fully restrained NPT at 20fs
$GMX grompp -f $MDP/npt_20fs.mdp -c npt_10fs.gro -r npt_10fs.gro -p system.top -o npt_20fs.tpr -t npt_10fs.cpt -maxwarn 1

$GMX mdrun -deffnm npt_20fs -v

# Unrestrained NPT at 20fs
$GMX grompp -f $MDP/prod.mdp -c npt_20fs.gro -p system.top -o prod.tpr -t npt_20fs.cpt -maxwarn 1

$GMX mdrun -deffnm prod -v


