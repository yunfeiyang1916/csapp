	.file	"store_uprod.c"
	.text
	.globl	store_uprod
	.def	store_uprod;	.scl	2;	.type	32;	.endef
	.seh_proc	store_uprod
store_uprod:
	.seh_endprologue
	movq	%rdx, %rax
	mulq	%r8
	movq	%rax, (%rcx)
	movq	%rdx, 8(%rcx)
	ret
	.seh_endproc
	.ident	"GCC: (x86_64-posix-sjlj-rev0, Built by MinGW-W64 project) 8.1.0"
