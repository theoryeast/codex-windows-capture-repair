; SPDX-License-Identifier: MIT
; Independently implemented x64 callback handoff. Only RCX (delegate) is kept.
; Compatible profiles must establish that sender/event-args are unused.
option casemap:none
EXTERN __imp_CreateThread:QWORD
EXTERN __imp_CloseHandle:QWORD
EXTERN __imp_RoInitialize:QWORD
EXTERN __imp_RoUninitialize:QWORD
EXTERN OriginalFrameArrived:PROC
PUBLIC DeferredFrameArrived
PUBLIC DeferredFrameWorker
.code
DeferredFrameArrived PROC FRAME
    sub rsp,38h
    .allocstack 38h
    .endprolog
    mov [rsp+30h],rcx
    mov rax,[rcx]
    call qword ptr [rax+8]
    xor ecx,ecx
    xor edx,edx
    lea r8,DeferredFrameWorker
    mov r9,[rsp+30h]
    xor eax,eax
    mov [rsp+20h],rax
    mov [rsp+28h],rax
    call qword ptr [__imp_CreateThread]
    test rax,rax
    jz dispatch_failed
    mov rcx,rax
    call qword ptr [__imp_CloseHandle]
    xor eax,eax
    add rsp,38h
    ret
dispatch_failed:
    mov rcx,[rsp+30h]
    mov rax,[rcx]
    call qword ptr [rax+10h]
    mov eax,80004005h
    add rsp,38h
    ret
DeferredFrameArrived ENDP

DeferredFrameWorker PROC FRAME
    sub rsp,38h
    .allocstack 38h
    .endprolog
    mov [rsp+30h],rcx
    mov ecx,1
    call qword ptr [__imp_RoInitialize]
    mov [rsp+28h],eax
    test eax,eax
    js release_delegate
    mov rcx,[rsp+30h]
    xor edx,edx
    xor r8d,r8d
    call OriginalFrameArrived
release_delegate:
    mov rcx,[rsp+30h]
    mov rax,[rcx]
    call qword ptr [rax+10h]
    cmp dword ptr [rsp+28h],0
    jl worker_done
    call qword ptr [__imp_RoUninitialize]
worker_done:
    xor eax,eax
    add rsp,38h
    ret
DeferredFrameWorker ENDP
END
