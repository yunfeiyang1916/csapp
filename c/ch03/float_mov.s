	.file	"float_mov.c"
	.text
	.globl	float_mov
	.def	float_mov;	.scl	2;	.type	32;	.endef
	.seh_proc	float_mov
float_mov:
	.seh_endprologue
	movss	(%rdx), %xmm1
	movss	%xmm0, (%r8)
	movaps	%xmm1, %xmm0
	ret
	.seh_endproc
	.ident	"GCC: (x86_64-posix-sjlj-rev0, Built by MinGW-W64 project) 8.1.0"
