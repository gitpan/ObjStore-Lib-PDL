extern "C" {
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "pdl.h"
}
#include <osperl.h>

struct Lib__PDL1 : OSSVPV {
  static os_typespec *get_os_typespec();

  I32 *dims;
  void *data;
  I16 datatype;
  I16 ndims;

  Lib__PDL1();
  virtual ~Lib__PDL1();
  virtual int get_perl_type();
  virtual void make_constant();
  virtual char *os_class(STRLEN *len);
  virtual char *rep_class(STRLEN *len);
  virtual dynacast_fn get_dynacast_meth();

  void clear();
  void copy(Lib__PDL1 &tmpl);
  void allocate_cells(U32, int);
  void set_datatype(int ndt);
  void setdims(I32 cnt, I32 *dsz, void *tmpl=0);
};
