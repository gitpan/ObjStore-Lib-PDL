/* partially ---C++-*- */

#include "ospdl.h"

extern "C" {
#define _pdlmagic_H_
#define new new_pdl
#include "pdlcore.h"
#undef new
}

// PDL redefines croak too!
#undef croak
#define croak osp_croak

static HV *PDLStash1;
static Core *PDLAPI;

Lib__PDL1::Lib__PDL1()
{
  data = 0;
  dims = 0;
  datatype = PDL_D;
  ndims = 0;
}

Lib__PDL1::~Lib__PDL1()
{
  if (data) delete [] data;
  if (dims) delete [] dims;
}

int Lib__PDL1::get_perl_type()
{ return SVt_PVMG; }

void Lib__PDL1::make_constant()
{ croak("not implemented"); }

char *Lib__PDL1::os_class(STRLEN *len)
{ *len = 18; return "ObjStore::Lib::PDL"; }

char *Lib__PDL1::rep_class(STRLEN *len)
{ *len = 18; return "ObjStore::Lib::PDL"; }

void Lib__PDL1::setdims(I32 cnt, I32 *dsz)
{
  int zero = ndims == 0;
  assert(cnt >= 0);
  if (data) { delete [] data; data=0; }
  if (dims) { delete [] dims; dims=0; }
  ndims = cnt;
  if (cnt > 0) {
    U32 bytes = 1;
    NEW_OS_ARRAY(dims, os_segment::of(this), os_typespec::get_signed_int(),
		 int, cnt);
    for (int xx=0; xx < cnt; xx++) {
      bytes *= dsz[xx];
      dims[xx] = dsz[xx];
    }
    bytes *= PDLAPI->howbig(datatype);
    if (bytes > 1024 * 1024 * 1024)
      croak("PDL size > 1GB; are you serious?");
    NEW_OS_ARRAY(data, os_segment::of(this), os_typespec::get_char(),
		 char, bytes);
    if (zero) Zero(data, bytes, char);
  }
}

void Lib__PDL1::set_datatype(int ndt)
{
  if (datatype == ndt) return;
  datatype = ndt;
  if (data) { delete [] data; data=0; }
  if (ndims > 0) {
	/* be smart about preserving existing values? XXX */
    U32 bytes = 1;
    for (int xx=0; xx < ndims; xx++) bytes += dims[xx];
    bytes *= PDLAPI->howbig(datatype);
    if (bytes > 1024 * 1024 * 1024)
      croak("PDL size > 1GB; are you serious?");
    NEW_OS_ARRAY(data, os_segment::of(this), os_typespec::get_char(),
		 char, bytes);
  }
}

//------------------------------------------------- typemap

struct pdl_bridge : osp_smart_object {
  osp_bridge_ring link; /*XXX*/
  pdl *proxy;
  pdl_bridge();
  void init(Lib__PDL1 *pv);
  virtual ~pdl_bridge();
};

pdl_bridge::pdl_bridge()
  : link(this)
{
  proxy = PDLAPI->create(PDL_PERM);
  proxy->state |= PDL_DONTTOUCHDATA | PDL_ALLOCATED;
}

void pdl_bridge::init(Lib__PDL1 *pv)
{
  if (proxy->ndims != pv->ndims) {
    if (proxy->dimincs != proxy->def_dimincs) free(proxy->dimincs);
    if (pv->ndims > PDL_NDIMS) {
        proxy->dimincs = (int*) malloc(pv->ndims*sizeof(*(proxy->dimincs)));
	if (!proxy->dimincs) croak("Out of memory");
    }
    else
	proxy->dimincs = proxy->def_dimincs;
  }
  proxy->datatype = pv->datatype;
  proxy->ndims = pv->ndims;
  proxy->dims = pv->dims;
  proxy->data = pv->data;

  int inc = 1;
  for (int i=0; i < proxy->ndims; i++) {
    proxy->dimincs[i] = inc; inc *= proxy->dims[i];
  }
  proxy->nvals = inc;
}

pdl_bridge::~pdl_bridge()
{
  proxy->data = 0;
  proxy->dims = proxy->def_dims;
  PDLAPI->destroy(proxy);
}

static void *ospdl_dynacast(void *obj, HV *stash)
{
  if (stash == osp_thr::BridgeStash) {
    return obj; /*already ok*/
  }
  else if (stash == PDLStash1) {
    ospv_bridge *br = (ospv_bridge*) obj;
    pdl_bridge *pdlbr;
    if (!br->info) {
	br->info = pdlbr = new pdl_bridge();
	pdlbr->init((Lib__PDL1*) br->ospv());
    }
    pdlbr = (pdl_bridge*) br->info;
    return pdlbr->proxy;
  }
  else {
    croak("Don't know how to convert ObjStore::Lib::PDL to a '%s'",
	 HvNAME(stash));
    return 0;
  }
}

dynacast_fn Lib__PDL1::get_dynacast_meth()
{ return ospdl_dynacast; }


MODULE = ObjStore::Lib::PDL	PACKAGE = ObjStore::Lib::PDL

PROTOTYPES: disable

BOOT:
  extern _Application_schema_info Lib__PDL_dll_schema_info;
  osp_thr::register_schema("ObjStore::Lib::PDL", &Lib__PDL_dll_schema_info);
  PDLStash1 = gv_stashpv("PDL", 1);
  SV *pdl_core_sv = perl_get_sv("PDL::SHARE", 0);
  if (!pdl_core_sv) croak("PDL is not loaded");
  PDLAPI = (Core*) SvIV(pdl_core_sv);
  assert(sizeof(PDL_Long) == sizeof(os_int32)); // Is this the only assumption?

void
_allocate(CSV, seg)
	SV *CSV;
	SV *seg;
	PPCODE:
	os_segment *area = osp_thr::sv_2segment(seg);
	PUTBACK;
	OSSVPV *pv;
	NEW_OS_OBJECT(pv, area, Lib__PDL1::get_os_typespec(), Lib__PDL1);
	pv->bless(CSV);
	return;

void
OSSVPV::setdims(sv)
	SV *sv
	CODE:
	if (!(SvROK(sv) && SvTYPE(SvRV(sv))==SVt_PVAV))
	  croak("setdims: expecting an array ref");
	AV *ar = (AV*) SvRV(sv);
	int ndims = av_len(ar)+1;
	I32 *dims;
	if (ndims) {
	  New(0, dims, ndims, I32);
	  for (int xx=0; xx < ndims; xx++)
	    dims[xx] = SvIV(*av_fetch(ar,xx,0));
	}
	((Lib__PDL1*)THIS)->setdims(ndims, dims);
	if (THIS_bridge->info)
	  ((pdl_bridge*) THIS_bridge->info)->init(((Lib__PDL1*)THIS));

void
OSSVPV::set_datatype(datatype)
	int datatype;
	CODE:
	((Lib__PDL1*)THIS)->set_datatype(datatype);
	if (THIS_bridge->info)
	  ((pdl_bridge*) THIS_bridge->info)->init(((Lib__PDL1*)THIS));

void
OSSVPV::upd_data()
	CODE:
	/* do nothing */

