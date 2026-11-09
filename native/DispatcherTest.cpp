// SPDX-License-Identifier: MIT
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <roapi.h>
#include <unknwn.h>
#include <atomic>
#include <cstdio>

extern "C" HRESULT DeferredFrameArrived(IUnknown*,void*,void*);
struct Delegate final : IUnknown {
    std::atomic<ULONG> refs{1};
    std::atomic<unsigned> calls{0},errors{0};
    DWORD caller=GetCurrentThreadId();
    HANDLE returned=CreateEventW(nullptr,TRUE,FALSE,nullptr);
    HANDLE completed=CreateEventW(nullptr,TRUE,FALSE,nullptr);
    ~Delegate(){CloseHandle(returned);CloseHandle(completed);}
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID,void** result) override{*result=this;AddRef();return S_OK;}
    ULONG STDMETHODCALLTYPE AddRef() override{return ++refs;}
    ULONG STDMETHODCALLTYPE Release() override{ULONG n=--refs;if(n==1)SetEvent(completed);return n;}
};
extern "C" HRESULT OriginalFrameArrived(IUnknown* self,void* sender,void* args){
    auto d=static_cast<Delegate*>(self);
    ++d->calls;
    if(sender || args || d->caller==GetCurrentThreadId())++d->errors;
    APTTYPE type{};APTTYPEQUALIFIER qualifier{};
    if(FAILED(CoGetApartmentType(&type,&qualifier)) || type!=APTTYPE_MTA)++d->errors;
    if(WaitForSingleObject(d->returned,2000)!=WAIT_OBJECT_0)++d->errors;
    return S_OK;
}
int main(){
    for(unsigned i=0;i<200;++i){
        Delegate d;
        HRESULT hr=DeferredFrameArrived(&d,nullptr,nullptr);
        SetEvent(d.returned);
        if(WaitForSingleObject(d.completed,3000)!=WAIT_OBJECT_0)return 2;
        if(FAILED(hr) || d.calls!=1 || d.errors || d.refs!=1){std::printf("FAIL iteration=%u\n",i);return 1;}
    }
    std::puts("PASS: 200 asynchronous MTA/refcount/return-order iterations");return 0;
}
