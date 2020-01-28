#!/bin/bash -l

set -e 

GMX=gmx

PDB=${1}
MDP=../../amber
$GMX pdb2gmx -f peptide.pdb -ff amber99sb-ildn -water tip3p -ignh

$GMX editconf -f conf.gro -d 1.0 -bt triclinic -o boxed.gro

$GMX solvate -cp boxed.gro -cs -o solvated.gro -p topol.top

$GMX grompp -f $MDP/em.mdp -c solvated.gro -p topol.top -o ions.tpr

echo SOL | $GMX genion -s ions.tpr -o neutralized.gro -p topol.top -neutral -conc 0.1

# Minization in Solvent
$GMX grompp -f $MDP/em.mdp -c neutralized.gro -p topol.top -o em.tpr

$GMX mdrun -deffnm em -v

# Restrained NVT 
$GMX grompp -f $MDP/nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr

$GMX mdrun -deffnm nvt -v

# Restrained NPT 
$GMX grompp -f $MDP/npt.mdp -c nvt.gro -r nvt.gro -p topol.top -o npt.tpr -t nvt.cpt

$GMX mdrun -deffnm npt -v

# Unrestrained NPT 
$GMX grompp -f $MDP/prod.mdp -c npt.gro -r npt.gro -p topol.top -o prod.tpr -t npt.cpt

$GMX mdrun -deffnm prod -v
