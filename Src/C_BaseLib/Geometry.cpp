//BL_COPYRIGHT_NOTICE

//
// $Id: Geometry.cpp,v 1.25 1998-06-16 18:02:04 lijewski Exp $
//

#include <Geometry.H>
#include <ParmParse.H>
#include <BoxArray.H>

//
// The definition of static data members.
//
RealBox Geometry::prob_domain;

bool Geometry::is_periodic[BL_SPACEDIM];

const int MaxFPBCacheSize = 10;

Geometry::FPBList Geometry::m_FPBCache;

ostream&
operator<< (ostream&        os,
            const Geometry& g)
{
    os << (CoordSys&) g;
    os << g.prob_domain;
    os << g.domain;
    return os;
}

istream&
operator>> (istream&  is,
            Geometry& g)
{
    is >> (CoordSys&) g;
    is >> g.prob_domain;
    is >> g.domain;
    return is;
}

ostream&
operator << (ostream&               os,
	     const Geometry::PIRec& pir)
{
    os << "mfi: "
       << pir.mfid
       << " from (Box "
       << pir.srcId
       << ") "
       << pir.srcBox
       << " to "
       << pir.dstBox;

    return os;
}

ostream&
operator<< (ostream&                 os,
	    const Geometry::PIRMMap& pirm)
{
    for (int i = 0; i < pirm.size(); i++)
    {
        os << pirm[i] << '\n';
    }
    return os;
}

void
Geometry::FlushPIRMCache ()
{
    m_FPBCache.clear();
}

Geometry::PIRMMap&
Geometry::buildPIRMMap (const BoxArray& grids,
                        int             nGrow,
                        bool            no_ovlp) const
{
    assert(isAnyPeriodic());

    if (m_FPBCache.size() == MaxFPBCacheSize)
    {
        m_FPBCache.pop_back();
    }
    //
    // Add new FPBs to the front of the cache.
    //
    m_FPBCache.push_front(FPB(grids,nGrow,no_ovlp));

    PIRMMap& pirm = m_FPBCache.front().m_pirm;
    //
    // Make a junk multifab for its iterator.  Don't allocate any mem for it.
    //
    MultiFab mf(grids, 1, nGrow, Fab_noallocate);

    Array<IntVect> pshifts(27);
    //
    // Do only those I own.
    //
    for (ConstMultiFabIterator mfi(mf); mfi.isValid(); ++mfi)
    {
        Box dest = ::grow(mfi.validbox(), nGrow);

        assert(dest.ixType().cellCentered() || dest.ixType().nodeCentered());

        if (no_ovlp)
        {
            const Box& validbox = mfi.validbox();

            for (int idir = 0; idir < BL_SPACEDIM; idir++)
            {
                //
                // Shrink box if the +/- direction is not physical boundary.
                //
                if (validbox.smallEnd(idir) != Domain().smallEnd(idir))
                {
                    dest.growLo(idir,-nGrow);
                }
                if (validbox.bigEnd(idir) != Domain().bigEnd(idir))
                {
                    dest.growHi(idir,-nGrow);
                }
            }
        }
        bool doit = false;

        if (dest.ixType().cellCentered())
        {
            doit = !Domain().contains(dest);
        }
        else
        {
            doit = !::grow(::surroundingNodes(Domain()),-1).contains(dest);
        }

        if (doit)
        {
            for (int j = 0; j < grids.length(); j++)
            {
                periodicShift(dest, grids[j], pshifts);

                for (int iiv = 0; iiv < pshifts.length(); iiv++)
                {
                    Box shbox(grids[j]);
                    shbox.shift(pshifts[iiv]);
                    Box srcBox = dest & shbox;
                    assert(srcBox.ok());
                    //
                    // OK, we got an intersection.
                    //
                    Box dstBox = srcBox;
                    dstBox.shift(-pshifts[iiv]);

                    pirm.push_back(PIRec(mfi.index(),j,dstBox,srcBox));
                }
            }
        }
    }

    return pirm;
}

MultiFabCopyDescriptor&
Geometry::theFPBmfcd (MultiFab& mf,
                      int       src_comp,
                      int       num_comp,
                      bool      no_ovlp,
                      PIRMMap&  pirm) const
{
    bool buildit;

    MultiFabCopyDescriptor& mfcd = mf.theFPBmfcd(src_comp,num_comp,
                                                 no_ovlp,buildit);

    if (buildit == false)
    {
        return mfcd;
    }
    //
    // Fill intersection list.
    //
    MultiFabId mfid = mfcd.RegisterMultiFab(&mf);

    assert(mfid == MultiFabId(0));
    //
    // Register boxes in copy descriptor.
    //
    for (int i = 0; i < pirm.size(); i++)
    {
        pirm[i].fbid = mfcd.AddBox(mfid,
                                   pirm[i].srcBox,
                                   0,
                                   pirm[i].srcId,
                                   src_comp,
                                   src_comp,
                                   num_comp);
    }

    return mfcd;
}

void
Geometry::FillPeriodicBoundary (MultiFab& mf,
                                int       src_comp,
                                int       num_comp,
                                bool      no_ovlp) const
{
    if (!isAnyPeriodic())
        return;

    RunStats stats("fill_periodic_bndry");

    stats.start();

    PIRMMap& pirm = getPIRMMap(mf.boxArray(),mf.nGrow(),no_ovlp);
    //
    // Get cached MultiFabCopyDescriptor.
    //
    MultiFabCopyDescriptor& mfcd = theFPBmfcd(mf,src_comp,num_comp,no_ovlp,pirm);
    //
    // Gather/scatter distributed data to (local) internal buffers.
    //
    mfcd.CollectData();

    const MultiFabId TheFPBMultiFabId(0);

    const int MyProc = ParallelDescriptor::MyProc();

    for (int i = 0; i < pirm.size(); i++)
    {
        assert(mf.ProcessorMap()[pirm[i].mfid] == MyProc);

        assert(pirm[i].fbid.box() == pirm[i].srcBox);

        mfcd.FillFab(TheFPBMultiFabId,
                     pirm[i].fbid,
                     mf[pirm[i].mfid],
                     pirm[i].dstBox);
    }

    stats.end();
}

Geometry::Geometry () {}

Geometry::Geometry (const Box& dom)
{
    define(dom);
}

Geometry::Geometry (const Geometry& g)
{
    define(g.domain);
}

Geometry::~Geometry() {}

void
Geometry::define (const Box& dom)
{
    if (c_sys == undef)
        Setup();
    domain = dom;
    ok = true;
    for (int k = 0; k < BL_SPACEDIM; k++)
    {
        dx[k] = prob_domain.length(k)/(Real(domain.length(k)));
    }
}

void
Geometry::Setup ()
{
    ParmParse pp("geometry");

    int coord;
    pp.get("coord_sys",coord);
    SetCoord( (CoordType) coord );

    Array<Real> prob_lo(BL_SPACEDIM);
    pp.getarr("prob_lo",prob_lo,0,BL_SPACEDIM);
    assert(prob_lo.length() == BL_SPACEDIM);
    Array<Real> prob_hi(BL_SPACEDIM);
    pp.getarr("prob_hi",prob_hi,0,BL_SPACEDIM);
    assert(prob_lo.length() == BL_SPACEDIM);
    prob_domain.setLo(prob_lo);
    prob_domain.setHi(prob_hi);
    //
    // Now get periodicity info.
    //
    D_EXPR( is_periodic[0]=0, is_periodic[1]=0, is_periodic[2]=0);
    if (pp.contains("period_0"))
    {
        is_periodic[0] = 1;
    }
#if BL_SPACEDIM>1
    if (pp.contains("period_1"))
    {
        is_periodic[1] = 1;
    }
#endif
#if BL_SPACEDIM>2
    if (pp.contains("period_2"))
    {
        is_periodic[2] = 1;
    }
#endif
}

void
Geometry::GetVolume (MultiFab&       vol,
                     const BoxArray& grds,
                     int             ngrow) const
{
    vol.define(grds,1,ngrow,Fab_noallocate);
    for (MultiFabIterator mfi(vol); mfi.isValid(); ++mfi)
    {
        Box gbx(grow(grds[mfi.index()],ngrow));
        vol.setFab(mfi.index(),CoordSys::GetVolume(gbx));
    }
}

#if (BL_SPACEDIM == 2)
void
Geometry::GetDLogA (MultiFab&       dloga,
                    const BoxArray& grds, 
                    int             dir,
                    int             ngrow) const
{
    dloga.define(grds,1,ngrow,Fab_noallocate);
    for (MultiFabIterator mfi(dloga); mfi.isValid(); ++mfi)
    {
        Box gbx(grow(grds[mfi.index()],ngrow));
        dloga.setFab(mfi.index(),CoordSys::GetDLogA(gbx,dir));
    }
}
#endif

void
Geometry::GetFaceArea (MultiFab&       area,
                       const BoxArray& grds,
                       int             dir,
                       int             ngrow) const
{
    BoxArray edge_boxes(grds);
    edge_boxes.surroundingNodes(dir);
    area.define(edge_boxes,1,ngrow,Fab_noallocate);
    for (MultiFabIterator mfi(area); mfi.isValid(); ++mfi)
    {
        Box gbx(grow(grds[mfi.index()],ngrow));
        area.setFab(mfi.index(),CoordSys::GetFaceArea(gbx,dir));
    }
}

void
Geometry::periodicShift (const Box&      target,
                         const Box&      src, 
                         Array<IntVect>& out) const
{
    Box locsrc(src);
    out.resize(0);

    int nist,njst,nkst;
    int niend,njend,nkend;
    nist = njst = nkst = 0;
    niend = njend = nkend = 0;
    D_TERM( nist , =njst , =nkst ) = -1;
    D_TERM( niend , =njend , =nkend ) = +1;

    int ri,rj,rk;
    for (ri = nist; ri <= niend; ri++)
    {
        if (ri != 0 && !is_periodic[0])
            continue;
        if (ri != 0 && is_periodic[0])
            locsrc.shift(0,ri*domain.length(0));

        for (rj = njst; rj <= njend; rj++)
        {
            if (rj != 0 && !is_periodic[1])
                continue;
            if (rj != 0 && is_periodic[1])
                locsrc.shift(1,rj*domain.length(1));

            for (rk = nkst; rk <= nkend; rk++)
            {
                if (rk!=0
#if (BL_SPACEDIM == 3)
                    && !is_periodic[2]
#endif
                    )
                {
                    continue;
                }
                if (rk!=0
#if (BL_SPACEDIM == 3)
                    && is_periodic[2]
#endif
                    )
                {
                    locsrc.shift(2,rk*domain.length(2));
                }

                if (ri == 0 && rj == 0 && rk == 0)
                    continue;
                //
                // If losrc intersects target, then add to "out".
                //
                if (target.intersects(locsrc))
                {
                    IntVect sh;
                    D_TERM(sh.setVal(0,ri*domain.length(0));,
                           sh.setVal(1,rj*domain.length(1));,
                           sh.setVal(2,rk*domain.length(2));)
                        out.resize(out.length()+1); 
                        out[out.length()-1] = sh;
                }
                if (rk != 0
#if (BL_SPACEDIM == 3)
                    && is_periodic[2]
#endif
                    )
                {
                    locsrc.shift(2,-rk*domain.length(2));
                }
            }
            if (rj != 0 && is_periodic[1])
                locsrc.shift(1,-rj*domain.length(1));
        }
        if (ri != 0 && is_periodic[0])
            locsrc.shift(0,-ri*domain.length(0));
    }
}
