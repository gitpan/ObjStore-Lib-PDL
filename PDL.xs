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
  dims = 0;
  datatype = PDL_D;
  ndims = 0;
  data = 0;
}

Lib__PDL1::~Lib__PDL1()
{ clear(); }

void Lib__PDL1::clear()
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

void Lib__PDL1::allocate_cells(U32 cnt, int zero)
{
  // Let ObjectStore know what type we are allocating...
  //   This is a mess.
  //
  // Suggestions?

  int width = PDLAPI->howbig(datatype);
  if (cnt > 1024 * 1024 * 1024) croak("PDL size > 1GB; are you serious?");
  switch (datatype) {
    case PDL_B:
      assert(width == sizeof(PDL_Byte) && width == sizeof(char));
      NEW_OS_ARRAY(data, os_segment::of(this), os_typespec::get_char(),
		 char, cnt);
      break;
    case PDL_S:
      assert(width == sizeof(PDL_Short) && width == sizeof(os_int16));
      NEW_OS_ARRAY(data, os_segment::of(this), os_typespec::get_signed_short(),
		 os_int16, cnt);
      break;
    case PDL_US:
      assert(width == sizeof(PDL_Ushort) && width == sizeof(os_unsigned_int16));
      NEW_OS_ARRAY(data, os_segment::of(this), os_typespec::get_unsigned_short(),
		 os_unsigned_int16, cnt);
      break;
    case PDL_L:
      assert(width == sizeof(PDL_Long) && width == sizeof(os_int32));
      NEW_OS_ARRAY(data, os_segment::of(this), os_typespec::get_long(),
		 os_int32, cnt);
      break;
    case PDL_F:
      assert(width == sizeof(PDL_Float) && width == sizeof(float));
      NEW_OS_ARRAY(data, os_segment::of(this), os_typespec::get_float(),
		 float, cnt);
      break;
    case PDL_D:
      assert(width == sizeof(PDL_Double) && width == sizeof(double));
      NEW_OS_ARRAY(data, os_segment::of(this), os_typespec::get_double(),
		 double, cnt);
      break;
    default:
      croak("Unknown datatype code = %d",datatype);
  }
  if (zero) Zero(data, cnt * width, char);
}

void Lib__PDL1::setdims(I32 cnt, I32 *dsz, void *tmpl)
{
  int zero = ndims == 0 && !tmpl;
  assert(cnt >= 0);
  if (data) { delete [] data; data=0; }
  if (dims) { delete [] dims; dims=0; }
  ndims = cnt;

  U32 cells = 1;
  NEW_OS_ARRAY(dims, os_segment::of(this), os_typespec::get_signed_int(),
		 int, cnt);
  for (int xx=0; xx < cnt; xx++) {
    cells *= dsz[xx];
    dims[xx] = dsz[xx];
  }
  allocate_cells(cells, zero);
  if (tmpl)
    Copy(tmpl, data, cells * PDLAPI->howbig(datatype), char);
}

void Lib__PDL1::set_datatype(int ndt)
{
  if (datatype == ndt) return;
  datatype = ndt;
  if (data) { delete [] data; data=0; }
	/* be smart about preserving existing values? XXX */
  U32 cnt = 1;
  for (int xx=0; xx < ndims; xx++) cnt += dims[xx];
  allocate_cells(cnt, 0);
}

void Lib__PDL1::copy(Lib__PDL1 &tmpl)
{
  clear();
  datatype = tmpl.datatype;
  ndims = 1;  //avoid Zero
  setdims(tmpl.ndims, tmpl.dims, tmpl.data);
}

//------------------------------------------------- typemap

static int bridge_counter = 0;
static osp_bridge_ring Freelist(0);

struct pdl_bridge : osp_smart_object {
  osp_bridge_ring link;
  pdl *proxy;
  pdl_bridge();
  void init(Lib__PDL1 *pv);
  virtual void freelist();
  virtual ~pdl_bridge();
};

pdl_bridge::pdl_bridge()
  : link(this)
{
  ++bridge_counter;
  proxy = PDLAPI->create(PDL_PERM);
  PDLAPI->SetSV_PDL(newSV(0), proxy);
  SvREFCNT_inc( (SV*) proxy->sv);  // is in our scope
//  sv_dump( (SV*) proxy->sv);
}

void pdl_bridge::init(Lib__PDL1 *pv)
{
  proxy->state = PDL_DONTTOUCHDATA | PDL_ALLOCATED;
  if (!pv->data) {
    assert(pv->ndims == 0);
    pv->allocate_cells(1, 1);
  }
  if (proxy->ndims != pv->ndims) {
    if (proxy->ndims > PDL_NDIMS)
	free(proxy->dimincs);
    if (pv->ndims > PDL_NDIMS) {
        proxy->dimincs = (int*) malloc(pv->ndims*sizeof(*(proxy->dimincs)));
	if (!proxy->dimincs) croak("Out of memory");
    }
    else
	proxy->dimincs = proxy->def_dimincs;
  }
  proxy->threadids = proxy->def_threadids;
  proxy->threadids[0] = pv->ndims;
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

void pdl_bridge::freelist()
{
  link.attach(&Freelist);
}

pdl_bridge::~pdl_bridge()
{
  --bridge_counter;
  proxy->data = 0;
  proxy->dims = proxy->def_dims;
  //warn("nuking %d", proxy);
  SvREFCNT_dec(proxy->sv);
}

static void *ospdl_dynacast(void *obj, HV *stash, int failok)
{
  if (stash == osp_thr::BridgeStash) {
    return obj; /*already ok*/
  }
  else if (stash == PDLStash1) {
    ospv_bridge *br = (ospv_bridge*) obj;
    pdl_bridge *pdlbr;
    if (!br->info) {
	if (Freelist.empty()) {
	  br->info = pdlbr = new pdl_bridge();
          //warn("creating proxy for 0x%x", br->ospv());
        }
	else {
	  br->info = pdlbr = (pdl_bridge*) Freelist.pop();
          //warn("reuse proxy for 0x%x", br->ospv());
        }
	pdlbr->init((Lib__PDL1*) br->ospv());
    }
    pdlbr = (pdl_bridge*) br->info;
    return pdlbr->proxy;
  }
  else {
    if (!failok)
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
  osp_thr::use("ObjStore::Lib::PDL", OSPERL_API_VERSION);
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
_PurgeFreelist()
	CODE:
	while (!Freelist.empty()) {
	  delete (pdl_bridge*) Freelist.pop();
	}
	if (0 && bridge_counter)
	  warn("ObjStore::Lib::PDL: %d proxies are still in use",
		bridge_counter);

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
copy(THIS)
	OSSVPV *THIS;
	PPCODE:
	OSSVPV *cpy;
	NEW_OS_OBJECT(cpy, os_segment::of(THIS), Lib__PDL1::get_os_typespec(),
		Lib__PDL1);
	((Lib__PDL1*)cpy)->copy(* (Lib__PDL1*)THIS);
	SV *me = osp_thr::ospv_2sv(cpy, 1);
	XPUSHs(me);

void
OSSVPV::upd_data()
	CODE:
	/* do nothing */

void
DESTROY(sv)
	SV *sv
	PPCODE:
	/* Need to avoid attempting to destroy real PDLs! */
	if (SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVMG) {
	  ospv_bridge* br = (ospv_bridge*) SvIV(sv);
	  if (br->dynacast == ospdl_dynacast)
	    br->leave_perl();
	}
