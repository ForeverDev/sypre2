#ifndef __SINTERP_H
#define __SINTERP_H

#define SIZE_MEM	65536
#define SIZE_STACK	1024

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

struct spy_state;

typedef struct spy_cfunc {
	s8		identifier[128];
	void	(*f)(struct spy_state*, u64, u64);
} spy_cfunc;

typedef struct spy_state {
	u64			ip;
	u64			sp;
	u64			fp;
	u64			cfp;
	u64			varmem;
	u64			labels[1024];
    // rax is the return register.  when opcode
    // 'SETRET' is seen, the value on the top
    // of the stack is loaded into rax.  when
    // 'LEAVE' is seen, the value in rax is
    // pushed onto the stack
    f64         rax;
	f64			mem[SIZE_MEM];
    // note the stack is not marked, only
    // memory is
	u8	        marks[SIZE_MEM];
	// array of c functions
	spy_cfunc	cfuncs[1024];
} spy_state;

spy_state*	spy_newstate();
u64			spy_malloc(spy_state*, u64);
void        spy_free(spy_state*, u64);
void		spy_runtimeError(spy_state*, const s8*);
void		spy_dumpMemory(spy_state*);
void		spy_run(spy_state*, const f64*, const f64*);
void		spy_executeBinaryFile(spy_state*, const s8*);

#endif
