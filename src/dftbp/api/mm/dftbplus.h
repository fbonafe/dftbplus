/*------------------------------------------------------------------------------------------------*/
/*  DFTB+: general package for performing fast atomistic simulations                              */
/*  Copyright (C) 2006 - 2025  DFTB+ developers group                                             */
/*                                                                                                */
/*  See the LICENSE file for terms of usage and distribution.                                     */
/*------------------------------------------------------------------------------------------------*/
#ifndef __DFTBPLUS_H__
#define __DFTBPLUS_H__

#define __DFTBPLUS_RELEASE__ "@RELEASE@"
#define __DFTBPLUS_API__ "@API_VERSION@"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Type containing the list of atoms and species to be passed to DFTB+.
 *
 * Used by DFTB+ as an opaque handler. Do not manipulate the content of this type directly!
 */
typedef struct DftbPlusAtomList {
  void *pDftbPlusAtomList;
} DftbPlusAtomList;


/**
 * Type containing the DFTB+ input tree.
 *
 * Used by DFTB+ as an opaque handler. Do not manipulate the content of this type directly!
 */
typedef struct {
  void *pDftbPlusInput;
} DftbPlusInput;


/**
 * Type containing the DFTB+ calculator.
 *
 * Used by DFTB+ as an opaque handler. Do not manipulate the content of this type directly!
 */
typedef struct DftbPlus {
  void * pDftbPlus;
} DftbPlus;


/**
 * Callback function signature for calculating external population dependant potential.
 *
 * DFTB+ would call it whenever the population has changed and the population dependant external
 * potential must be recalculated.
 *
 * \param refptr[in] Reference pointer. This is the pointer you passed to DFTB+ when the call-back
 *     functions had been registered. You can use it to find the data you want to use to calculate
 *     the external potential.

 * \param dqatom[in] Population difference with respect to reference population (usually the neutral
 *     atom). Shape: [natom]. Note: Population means electrons, so a positive number indicates
 *     electron excess.
 *
 * \param extpotatom[out] Potential at the position of each qm-atom. Shape: [natom]. Note: It
 *     should be the potential as felt by an electron (negative potential value means attraction
 *     for an electron). Unit: Hartree.
 */
typedef void (*ExtPotFunc)(void *refptr, double *dqatom, double *extpotatom);


/**
 * Callback function signature for calculating external population dependant potential gradient.
 *
 * DFTB+ would call it whenever the forces are calculated and the population dependant external
 * potential must be taken into account.
 *
 * \param refptr[in] Reference pointer. This is the pointer you passed to DFTB+ when the call-back
 *     functions had been registered. You can use it to find the data you want to use to calculate
 *     the external potential gradient.
 *
 * \param dqatom[in] Population difference with respect to reference population (usually the
 *     neutral atom). Shape: [natom]. Note: Population means electrons, so a positive number
 *     indicates electron excess.
 *
 * \param extpotatomgrad[out] Potential gradient at the position of each qm-atom. Shape: [natom,
 *     3]. Note: It should be the gradient of the potential as felt by an electron (negative
 *     potential value means attraction for an electron). Unit: Hartree/Bohr.
 */
typedef void (*ExtPotGradFunc)(void *refptr, double *dqatom, double *extpotatomgrad);


/**
 * Returns current version of the DFTB+ API
 *
 * \param[out] major Major release number.
 *
 * \param[out] minor Minor release number.
 *
 * \param[out] patch Patch of release.
 */
void dftbp_api(int *major, int *minor, int *patch);


/**
 * Returns whether library was built with instance safe components only.
 *
 * Instance safe API support the creation of multiple concurrent DFTB+ instances within one process.
 *
 * \return Whether API is instance safe.
 */
_Bool dftbp_is_instance_safe();


/**
 * Finalizes a DftbPlusInput instance.
 *
 * \param[inout] instance Handler of the DftbPlusInput instance.
*/
void dftbp_input_final(DftbPlusInput *instance);


/**
 * Initializes a DFTB+ calculator.
 *
 * \param[inout] instance Handler of DFTB+ instance.
 *
 * \param[in] outputfilename Name of the file, where the DFTB+ screen output should be written.
 *     If you pass NULL, it will be written to standard output. If you pass any other file name as a
 *     C string, it will be opened, and the output will be written there. Pass "/dev/null" to
 *     suppress output.
 */
void dftbp_init(DftbPlus *instance, const char *outputfilename);


/**
 * Initializes a DFTB+ calculator (MPI-version).
 *
 * \param[inout] instance Handler of DFTB+ instance.
 *
 * \param[in] outputfilename Name of the file, where the DFTB+ screen output should be written.
 *     If you pass NULL, it will be written to standard output. If you pass any other file name as a
 *     C string, it will be opened, and the output will be written there. Pass "/dev/null" to
 *     suppress output.
 *
 * \param[in] mpiComm MPI-communicator id. Before calling, you must convert your MPI-communicator
 *     with the mpi_comm_c2f() function to a Fortran MPI-communicator id.
 */
void dftbp_init_mpi(DftbPlus *instance, const char *outputfilename, int mpiComm);


/**
 * Finalizes a DFTB+ calculator.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 */
void dftbp_final(DftbPlus *instance);


/**
 * Fills up a DFTB+ input tree from a HSD input file.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[in] filename Name of the file containing the HSD-input for DFTB+.
 *
 * \param[inout] input Handler containing the input tree parsed from the input file.
 */
void dftbp_get_input_from_file(DftbPlus *instance, const char *filename, DftbPlusInput *input);


/**
 * Sets up the calculator by processing a given input tree.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[inout] input The tree containing the DFTB+ input. On return, it contains the tree
 *     extended by all the default options set by the parser.
 */
void dftbp_process_input(DftbPlus *instance, DftbPlusInput *input);


/**
 * Sets a constant (charge independent) external potential.
 *
 * Note: It should be the potential as felt by an electron (negative potential value means
 *     attraction for an electron).
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[in] extpot External potential at the position of each atom. Shape: [natom]. Unit: Hartree.
 *
 * \param[in] extpotgrad Gradient of the external potential at each atom. Shape: [natom, 3]. Unit:
 *     Hartree/Bohr. This parameter is optional, you can pass NULL if you did not ask DFTB+ to
 *     calculate forces.
 */
void dftbp_set_external_potential(DftbPlus *instance, const double *extpot,
                                  const double *extpotgrad);


/**
 * Registers callback functions for population dependant external potential calculation.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[in] refptr Arbitrary pointer. DFTB+ will pass back this pointer unaltered when calling
 *     the registered functions. You can typically use it to pass a pointer to the data struct
 *     or class which contains the necessary data for the potential calculation. If your data
 *     is in the global space and you do not need it, pass an arbitrary pointer, e.g. NULL.
 *
 * \param[in] extpot Function pointer to the call-back function which DFTB+ should call, whenever
 *     the population dependant external potential should be calculated.
 *
 * \param[in] extpotgrad Function pointer to the call-back function which DFTB+ should call,
 *     whenever the gradient of the population dependant external potential should be calculated.
 */
void dftbp_register_ext_pot_generator(DftbPlus *instance, const void *refptr, ExtPotFunc extpot,
                                      ExtPotGradFunc extpotgrad);


/**
 * Sets actual atom coordinates.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[in] coords Coordinates of the atoms. Shape: [natom, 3]. Unit: Bohr.
 */
void dftbp_set_coords(DftbPlus *instance, const double *coords);


/**
 * Sets actual atom coordinates and lattice vectors.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[in] coords Coordinates of the atoms in atomic units. Shape: [natom, 3]. Unit: Bohr.
 *
 * \param[in] latvecs Lattice vectors. Shape: [3, 3]. Unit: Bohr.
 */
void dftbp_set_coords_and_lattice_vecs(DftbPlus *instance, const double *coords,
                                       const double *latvecs);


/**
 * Sets actual atom coordinates, lattice vectors and coordinate origin.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[in] coords Coordinates of the atoms in atomic units. Shape: [natom, 3]. Unit: Bohr.
 *
 * \param[in] latvecs Lattice vectors. Shape: [3, 3]. Unit: Bohr.
 *
 * \param[in] origin Coordinate origin. Shape: [3]. Unit: Bohr.
 */
void dftbp_set_coords_lattice_origin(DftbPlus *instance, const double *coords,
                                       const double *latvecs, const double *origin);

/**
 * Sets the neighbour list.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[in] nAllAtom Number of neighbour atoms in all interacting cells, which is usually much
 *     larger than natom
 *
 * \param[in] nMaxNeighbours Maximum number of neighbours an atom can have
 *
 * \param[in] nNeighbours Number of neighbours of an atom Shape: [natom].
 *
 * \param[in] neighbourIndex References to neighbour atoms for an atom in the central cell. This
 *     index is used to query the values of coordNeighbours and neighbour2CentCell
 *     Shape: [nMaxNeighbours, natom].
 *
 * \param[in] neighbourDistance Distances to neighbour atoms for an atom in the central cell
 *     Shape: [nMaxNeighbours, natom].
 *
 * \param[in] cutoff Cutoff used to compute the neighbour list Unit: Bohr.
 *
 * \param[in] coordNeighbours Coordinates of all neighbour atom in all cells
 *     Shape: [3, nAllAtom]. Unit: Bohr.
 *
 * \param[in] neighbour2CentCell Index of the atom in the central cell a neighbour atom corresponds
 *     to Shape: [nAllAtom].
 *
 */
void dftbp_set_neighbour_list(DftbPlus *instance, const int nAllAtom, const int nMaxNeighbours,
                                       const int *nNeighbours, const int *neighbourIndex,
                                       const double *neighbourDistance, const double cutoff,
                                       const double *coordNeighbours,
                                       const int *neighbour2CentCell);


/**
 * Queries the nr. of atoms in the system.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \return Nr. of atoms.
 */
int dftbp_get_nr_atoms(DftbPlus *instance);


/**
 * Queries the nr. of k-points in the system.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \return Nr. of k-points.
 */
int dftbp_nr_kpoints(DftbPlus *instance);


/**
 * Queries the energy of the current geometry.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[out] mermin_energy Mermin free energy of the current geometry. Unit: Bohr.
 */
void dftbp_get_energy(DftbPlus *instance, double *mermin_energy);


/**
 * Queries the gradients of the current geometry.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[out] gradients Gradients (not forces!) on each atom. Shape: [natom, 3]. Unit: Hartree/Bohr.
 */
void dftbp_get_gradients(DftbPlus *instance, double *gradients);


/**
 * Queries the number of basis functions for each atom in current geometry.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[out] nOrbitals Number of orbitals on each atom. Shape: [natom].
 */
void dftbp_get_nr_orbitals(DftbPlus *instance, int *nOrbitals);


/**
 * Queries the masses for each atom in current geometry.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[out] masses Mass of each atom. Shape: [natom].
 */
void dftbp_get_masses(DftbPlus *instance, double *masses);


/**
 * Queries the maximum cutoff distance used for interactions.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \return Cutoff distance Unit: Bohr.
 */
double dftbp_get_cutoff(DftbPlus *instance);


/**
 * Queries the stress tensor of the current periodic box.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[out] stresstensor Stress tensor for the periodic box. Shape: [3, 3]. Unit: Pascals.
 */
void dftbp_get_stress_tensor(DftbPlus *instance, double *stresstensor);


/**
 * Queries the net populations on the atoms.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[out] charges Net charges on each atom. Shape: [natom]. Sign convention: Electron has
 *     negative charge, so negative values indicate electron excess.
 */
void dftbp_get_gross_charges(DftbPlus *instance, double *charges);


/**
 * Queries the CM5 charges on the atoms.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[out] charges Net charges on each atom. Shape: [natom]. Sign convention: Electron has
 *     negative charge, so negative values indicate electron excess.
 */
void dftbp_get_cm5_charges(DftbPlus *instance, double *charges);


/**
 * Queries the reference valence charges of the atoms (effective Z).
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[out] charges reference charges on each atom. Shape: [natom].
 */
void dftbp_get_ref_charges(DftbPlus *instance, double *charges);


/**
 * Sets the reference valence charges of the atoms (effective Z).
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[in] charges reference charges on each atomic shell. Shape: [natom].
 */
void dftbp_set_ref_charges(DftbPlus *instance, double *charges);


/**
 * Queries electrostatic potential in specific points.
 *
 * \param[inout] instance Handler of the DFTB+ instance.
 *
 * \param[in] nLocations Number of requested points.
 *
 * \param[out] potential Values of electrostatic potential. Shape: [nLocations].
 *
 * \param[in] locations Coordinates of requested points. Shape: [nLocations, 3]. Unit: Bohr.
 */
void dftbp_get_elstat_potential(DftbPlus *instance, int nLocations, double *potential, const double *locations);

#ifdef __cplusplus
}
#endif

#endif
