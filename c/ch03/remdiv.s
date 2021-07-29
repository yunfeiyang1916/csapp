	.file	"remdiv.c"
	.text
	.globl	remdiv
	.def	remdiv;	.scl	2;	.type	32;	.endef
	.seh_proc	remdiv
remdiv:
	.seh_endprologue
	movl	%ecx, %eax
	movl	%edx, %r10d
	movl	$0, %edx
	divl	%r10d
	movl	%eax, (%r8)
	movl	%edx, (%r9)
	ret
	.seh_endproc
	.ident	"GCC: (x86_64-posix-sjlj-rev0, Built by MinGW-W64 project) 8.1.0"
