#include "amr-wind/wind_energy/ABLFillInflow.H"

namespace amr_wind {

ABLFillInflow::ABLFillInflow(
    Field& field,
    const amrex::AmrCore& mesh,
    const SimTime& time,
    const ABLBoundaryPlane& bndry_plane)
    : FieldFillPatchOps<FieldBCNoOp>(
          field, mesh, time, FieldInterpolator::CellConsLinear)
    , m_bndry_plane(bndry_plane)
{}

ABLFillInflow::~ABLFillInflow() = default;

void ABLFillInflow::fillpatch(
    int lev,
    amrex::Real time,
    amrex::MultiFab& mfab,
    const amrex::IntVect& nghost,
    const FieldState fstate)
{
    FieldFillPatchOps<FieldBCNoOp>::fillpatch(lev, time, mfab, nghost, fstate);

    m_bndry_plane.populate_data(lev, time, m_field, mfab);
}

void ABLFillInflow::fillpatch_from_coarse(
    int lev,
    amrex::Real time,
    amrex::MultiFab& mfab,
    const amrex::IntVect& nghost,
    const FieldState fstate)
{
    FieldFillPatchOps<FieldBCNoOp>::fillpatch_from_coarse(
        lev, time, mfab, nghost, fstate);

    m_bndry_plane.populate_data(lev, time, m_field, mfab);
}

void ABLFillInflow::fillphysbc(
    int lev,
    amrex::Real time,
    amrex::MultiFab& mfab,
    const amrex::IntVect& nghost,
    const FieldState fstate)
{
    FieldFillPatchOps<FieldBCNoOp>::fillphysbc(lev, time, mfab, nghost, fstate);

    m_bndry_plane.populate_data(lev, time, m_field, mfab);
}

} // namespace amr_wind
