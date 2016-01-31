#ifndef __SLIB_H
#define __SLIB_H

static void		spy_io_print(spy_state*, u64, u64);
static void		spy_io_println(spy_state*, u64, u64);

static void		spy_math_max(spy_state*, u64, u64);
static void		spy_math_min(spy_state*, u64, u64);
static void		spy_math_sin(spy_state*, u64, u64);
static void		spy_math_cos(spy_state*, u64, u64);
static void		spy_math_tan(spy_state*, u64, u64);
static void		spy_math_rad(spy_state*, u64, u64);
static void		spy_math_deg(spy_state*, u64, u64);
static void		spy_math_sqrt(spy_state*, u64, u64);
static void		spy_math_map(spy_state*, u64, u64);
static void		spy_math_plot(spy_state*, u64, u64);

void			spy_loadlibs(spy_state*);

#endif
