//! \file moving-cloud.cpp
//! \brief Problem generator a moving (cold) cloud in an ambient (hot) medium
//!

// C++ headers
// #include <algorithm> // min, max
// #include <cmath>     // log
// #include <cstring>   // strcmp()

// Parthenon headers
#include "mesh/mesh.hpp"
#include <basic_types.hpp>
// #include <iomanip>
// #include <ios>
#include <iostream>
#include <ostream>
#include <parthenon/driver.hpp>
#include <parthenon/package.hpp>
// #include <random>
// #include <sstream>

// AthenaPK headers
#include "../main.hpp" // Use of IDN indices and more
#include "../units.hpp"

namespace moving_cloud {
// Easier access to classes like 'Mesh', 'ParameterInput' etc.
using namespace parthenon::driver::prelude;

//========================================================================================
//! \fn void InitUserMeshData(Mesh *mesh, ParameterInput *pin)
//  \brief Function to initialize problem-specific data in mesh class.  Can also be used
//  to initialize variables which are global to (and therefore can be passed to) other
//  functions in this file.  Called in Mesh constructor.
//========================================================================================

void InitUserMeshData(Mesh *mesh, ParameterInput *pin) {
  // Hydro quantities useful for computations
  const auto &pkg = mesh->packages.Get("Hydro");
  const Real mbar_over_kb = pkg->Param<Real>("mbar_over_kb"); // == mu * m_H / k_B

  // Obtain the units
  Units units = pkg->Param<Units>("units");
  Real cm3 = units.cm() * units.cm() * units.cm();
  Real mh_per_cm3 = units.mh() / cm3;

  // By definition, we will keep rho_ambient == 1 in code units. This needs to be
  // specified in the input file, so there is some 'danger' of inconsistencies.
  // The rho_ambient variable is therefore more used as a check.
  //
  // Input variables
  Real i_rho_ambient =
      pin->GetReal("problem/moving_cloud", "rho_ambient_mh_cm3") * mh_per_cm3;
  Real T_ambient = pin->GetReal("problem/moving_cloud", "T_ambient_K"); // in Kelvin
  Real T_cloud = pin->GetReal("problem/moving_cloud", "T_cloud_K");     // in Kelvin

  // Factor that related the cloud radius to the code length unit (default 1.1)
  Real cloud_radius_factor =
      pin->GetOrAddReal("problem/moving_cloud", "cloud_radius_factor", 1.1);
  // Quantities we need to set up the problem:
  Real velocity_cloud =
      pin->GetReal("problem/moving_cloud", "velocity_cloud_km_s") * units.km_s();

  // Real rho_ambient = 1.0; // By definition
  Real rho_ambient = i_rho_ambient; // By definition
  Real rho_cloud = rho_ambient * T_ambient / T_cloud;
  Real pressure = rho_ambient * T_ambient / mbar_over_kb;

  if (std::abs(i_rho_ambient - rho_ambient) > 1e-8) {
    std::cout << "input: " << i_rho_ambient << ", and rho_ambient: " << rho_ambient
              << std::endl;
    PARTHENON_FAIL("Inconsistent input: rho_ambient_mh_cm3 must be set such that "
                   "rho_ambient == 1.0 in code units.");
  }

  // Store parameters in the Hydro package for access in other functions
  pkg->AddParam<Real>("moving_cloud/velocity_cloud", velocity_cloud);
  pkg->AddParam<Real>("moving_cloud/rho_ambient", rho_ambient);
  pkg->AddParam<Real>("moving_cloud/rho_cloud", rho_cloud);
  pkg->AddParam<Real>("moving_cloud/pressure", pressure);
  pkg->AddParam<Real>("moving_cloud/cloud_radius_factor", cloud_radius_factor);

  // Now report the setup
  std::stringstream msg;
  msg << std::setprecision(2);
  msg << "######################################" << std::endl;
  msg << "###### Moving cloud problem generator" << std::endl;
  msg << "#### Input parameters" << std::endl;
  msg << "## Ambient density:     " << rho_ambient / mh_per_cm3 << " mh/cm^3"
      << std::endl;
  msg << "## Ambient temperature: " << T_ambient << " K" << std::endl;
  msg << "## Cloud temperature:   " << T_cloud << " K" << std::endl;
  msg << "## Cloud velocity:      " << velocity_cloud / units.km_s()
      << " km/s = " << velocity_cloud << " code units" << std::endl;
  msg << "#### Derived parameters" << std::endl;
  msg << "## Cloud density: " << rho_cloud / mh_per_cm3 << " mh/cm^3 = " << rho_cloud
      << " code units" << std::endl;
  msg << "## Uniform pressure: " << pressure / (units.erg() / cm3)
      << "erg / cm3 = " << pressure << " code units" << std::endl;
  msg << "## Cloud to ambient density ratio: " << rho_cloud / rho_ambient << std::endl;
  msg << "######################################" << std::endl;
  msg << std::endl;
  msg << "######################################" << std::endl;
  msg << "#### Problem units" << std::endl;
  msg << "## Length unit: " << cloud_radius_factor << " x cloud radius" << std::endl;
  msg << "##              " << units.code_length_cgs() << " cm = " << 1 / units.kpc()
      << " kpc " << std::endl;
  msg << "## Mass unit:   " << units.code_mass_cgs() << " g = " << 1 / units.msun()
      << " M_sol " << std::endl;
  msg << "## Time unit:   " << units.code_time_cgs() << " s = " << 1 / units.myr()
      << " Myr " << std::endl;
  msg << "######################################" << std::endl;

  if (parthenon::Globals::my_rank == 0) {
    // Only output from the host
    std::cout << msg.str();
  }
};

//----------------------------------------------------------------------------------------
//! \fn void MeshBlock::ProblemGenerator(ParameterInput *pin)
//  \brief Problem Generator for the cloud in wind setup
void ProblemGenerator(MeshBlock *pmb, ParameterInput *pin) {
  auto hydro_pkg = pmb->packages.Get("Hydro");
  auto ib = pmb->cellbounds.GetBoundsI(IndexDomain::interior);
  auto jb = pmb->cellbounds.GetBoundsJ(IndexDomain::interior);
  auto kb = pmb->cellbounds.GetBoundsK(IndexDomain::interior);

  // Real gamma = hydro_pkg->Param<Real>("AdiabaticIndex");
  Real gamma = pin->GetReal("hydro", "gamma");

  // Retrieve the stored parameters
  const Real velocity_cloud = hydro_pkg->Param<Real>("moving_cloud/velocity_cloud");
  const Real rho_ambient = hydro_pkg->Param<Real>("moving_cloud/rho_ambient");
  const Real rho_cloud = hydro_pkg->Param<Real>("moving_cloud/rho_cloud");
  const Real pressure = hydro_pkg->Param<Real>("moving_cloud/pressure");
  const Real cloud_radius_factor =
      hydro_pkg->Param<Real>("moving_cloud/cloud_radius_factor");

  // initialize conserved variables
  auto &mbd = pmb->meshblock_data.Get();
  auto &u_dev = mbd->Get("cons").data;
  auto &coords = pmb->coords;
  // initializing on host
  auto u = u_dev.GetHostMirrorAndCopy();

  for (int k = kb.s; k <= kb.e; k++) {
    for (int j = jb.s; j <= jb.e; j++) {
      for (int i = ib.s; i <= ib.e; i++) {
        const Real x = coords.Xc<1>(i);
        const Real y = coords.Xc<2>(j);
        const Real z = coords.Xc<3>(k);

        // Define radius from the cloud center hardcoded at x = y = z = 0
        const Real rad = std::sqrt(SQR(x) + SQR(y) + SQR(z));
        // Radius in units of cloud radius
        const Real rad_cl = rad * cloud_radius_factor;

        Real steepness = 10;
        Real rho = rho_ambient + 0.5 * (rho_cloud - rho_ambient) *
                                     (1.0 - std::tanh(steepness * (rad_cl - 1.0)));

        Real velocity = 0 + 0.5 * (velocity_cloud - 0) *
                                (1.0 - std::tanh(steepness * (rad_cl - 1.0)));

        // Real velocity;
        // TODO: Factor 1.3 as used in Grønnow, Tepper-García, & Bland-Hawthorn 2018,
        // but check what is good
        // if (rad_cl <= 1.1) { // Inside the cloud + a little outside
        //   // rho = rho_cloud;
        //   velocity = velocity_cloud;
        // } else { // Ambient medium
        //   // rho = rho_ambient;
        //   velocity = 0.0;
        // }

        u(IDN, k, j, i) = rho;
        u(IM1, k, j, i) = rho * velocity; // Moving cloud in x-direction
        u(IM2, k, j, i) = 0.0;
        u(IM3, k, j, i) = 0.0;
        u(IEN, k, j, i) =
            pressure / (gamma - 1) +
            (SQR(u(IM1, k, j, i)) + SQR(u(IM2, k, j, i)) + SQR(u(IM3, k, j, i))) /
                (2.0 * u(IDN, k, j, i));

        // TODO: if MHD is used, initialize the field here...
        // TODO: if passive scalars are used, initialize here
      }
    }
  }

  // copy initialized vars to device
  u_dev.DeepCopy(u);
};

} // namespace moving_cloud
