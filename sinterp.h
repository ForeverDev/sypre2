#ifndef __SINTERP_H
#define __SINTERP_H

#define SIZE_MEM	65536
#define SIZE_STACK	1024

#define TYPE_NULL	0
#define TYPE_INT	1
#define TYPE_FLOAT	2
#define TYPE_PTR	3

typedef unsigned char		u8;
typedef unsigned short		u16;
typedef unsigned int		u32;
typedef unsigned long long	u64;

typedef char				s8;
typedef short				s16;
typedef int					s32;
typedef long long			s64;		

typedef float				f32;
typedef double				f64;

typedef struct tag_spy_data {
	u8 type;
	union {
		s64 ival;
		f64 fval;
		u64 pval;
	};
} spy_data;

struct tag_spy_state {
	u64 ip;
	u64 sp;
	u64 fp;	
	u64 mem[SIZE_MEM]; 
	u8	marks[SIZE_MEM];
} spy_state;

spy_state*	spy_newstate();
u64			spy_malloc(spy_state*, u64);
void		spy_runtimeError(spy_state*, const u8*);
void		spy_run(spy_state*, u64*);

#endif
