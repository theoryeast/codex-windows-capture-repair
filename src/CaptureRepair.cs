// SPDX-License-Identifier: MIT
using System;
using System.IO;
using System.Text;
using System.Security.Cryptography;
using System.Runtime.InteropServices;

// PE transformation for the reviewed 0.7.17 code layout only.
// No input, capture, approval, certificate-trust or system-policy API is called.
public static class CaptureRepairPE {
    public static string Hash(byte[] value) {
        using (var sha=SHA256.Create()) {return BitConverter.ToString(sha.ComputeHash(value)).Replace("-","").ToLowerInvariant();}
    }
    static ushort U16(byte[] b,int o){return BitConverter.ToUInt16(b,o);}
    static uint U32(byte[] b,int o){return BitConverter.ToUInt32(b,o);}
    static ulong U64(byte[] b,int o){return BitConverter.ToUInt64(b,o);}
    static void P16(byte[] b,int o,ushort n){Buffer.BlockCopy(BitConverter.GetBytes(n),0,b,o,2);}
    static void P32(byte[] b,int o,uint n){Buffer.BlockCopy(BitConverter.GetBytes(n),0,b,o,4);}
    static void P64(byte[] b,int o,ulong n){Buffer.BlockCopy(BitConverter.GetBytes(n),0,b,o,8);}
    static int Align(int n,int a){return checked((n+a-1)/a*a);}
    static bool Equal(byte[] a,int x,byte[] b,int y,int length) {
        for(int i=0;i<length;i++)if(a[x+i]!=b[y+i])return false;return true;
    }
    sealed class PE {
        public int pe,opt,headers,sectionTable; public Section[] sections;
        public PE(byte[] b) {
            if(b.Length<1024 || U16(b,0)!=0x5a4d)throw new Exception("Not a supported PE file.");
            pe=checked((int)U32(b,0x3c));opt=pe+24;
            if(pe<0 || opt+240>b.Length || U32(b,pe)!=0x4550 || U16(b,pe+4)!=0x8664 || U16(b,opt)!=0x20b)throw new Exception("Expected an x64 PE32+ helper.");
            headers=checked((int)U32(b,opt+60));sectionTable=opt+U16(b,pe+20);
            int count=U16(b,pe+6);
            if(count>32 || headers>b.Length || sectionTable+count*40>headers)throw new Exception("Invalid PE header.");
            sections=new Section[count];
            for(int i=0;i<count;i++) {
                int h=sectionTable+i*40;
                var s=new Section();s.name=Encoding.ASCII.GetString(b,h,8).TrimEnd('\0');s.header=h;
                s.virtualSize=U32(b,h+8);s.rva=U32(b,h+12);s.size=U32(b,h+16);s.raw=U32(b,h+20);
                if((ulong)s.raw+s.size>(ulong)b.Length)throw new Exception("Section is outside the file.");
                sections[i]=s;
            }
        }
        public int Offset(uint rva) {
            foreach(var s in sections)if(rva>=s.rva && rva-s.rva<s.size)return checked((int)(s.raw+rva-s.rva));
            throw new Exception("RVA is not backed by file data.");
        }
    }
    sealed class Section {public string name;public int header;public uint virtualSize,rva,size,raw;}
    public static void ValidateOriginal(byte[] b,string headerHash,string[] expectedSections) {
        var p=new PE(b);
        if(p.sections.Length!=9 || expectedSections.Length!=9)throw new Exception("Unsupported helper layout; a reviewed profile is required.");
        var normalized=new byte[p.headers];Buffer.BlockCopy(b,0,normalized,0,p.headers);
        foreach(int offset in new int[]{p.pe+8,p.opt+64,p.opt+144})Array.Clear(normalized,offset,offset==p.opt+144?8:4);
        if(Hash(normalized)!=headerHash)throw new Exception("Unsupported PE metadata; no files changed.");
        for(int i=0;i<p.sections.Length;i++) {
            var s=p.sections[i];string[] f=expectedSections[i].Split('|');
            if(f.Length!=7 || s.name!=f[0] || s.rva!=Convert.ToUInt32(f[1],16) || s.virtualSize!=Convert.ToUInt32(f[2],16) || s.raw!=Convert.ToUInt32(f[3],16) || s.size!=Convert.ToUInt32(f[4],16) || U32(b,s.header+36)!=Convert.ToUInt32(f[5],16))throw new Exception("Unsupported section layout: "+s.name);
            var bytes=new byte[s.size];Buffer.BlockCopy(b,(int)s.raw,bytes,0,(int)s.size);
            if(Hash(bytes)!=f[6])throw new Exception("Unsupported helper code/data: "+s.name+". No files changed.");
        }
        if(U64(b,p.Offset(0x12cf00))!=U64(b,p.opt+24)+0x4247aUL)throw new Exception("Callback entry mismatch.");
    }
    public static byte[] Build(byte[] original,string headerHash,string[] expectedSections) {
        ValidateOriginal(original,headerHash,expectedSections);
        byte[] payload=CaptureDispatcher.Payload(0x17c000);
        var p=new PE(original);int raw=Align(original.Length,512),rva=0x17c000;
        byte[] b=new byte[checked(raw+512)];Buffer.BlockCopy(original,0,b,0,original.Length);Buffer.BlockCopy(payload,0,b,raw,payload.Length);
        int h=p.sectionTable+9*40;for(int i=0;i<40;i++)if(b[h+i]!=0)throw new Exception("No unused section header.");
        Buffer.BlockCopy(Encoding.ASCII.GetBytes(".wgcmta\0"),0,b,h,8);
        P32(b,h+8,184);P32(b,h+12,(uint)rva);P32(b,h+16,512);P32(b,h+20,(uint)raw);P32(b,h+36,0x60000020);
        P16(b,p.pe+6,10);P32(b,p.opt+4,U32(original,p.opt+4)+512);P32(b,p.opt+56,0x17d000);
        P32(b,p.opt+64,0);P32(b,p.opt+144,0);P32(b,p.opt+148,0);
        P64(b,p.Offset(0x12cf00),U64(original,p.opt+24)+(ulong)rva);
        int oldSize=checked((int)U32(original,p.opt+140));
        if(oldSize!=0x8484)throw new Exception("Unexpected unwind table size.");
        int at=p.Offset(0x150000)+oldSize;
        for(int i=0;i<24;i++)if(b[at+i]!=0)throw new Exception("Unwind padding is occupied.");
        uint[] table={0x17c000,0x17c05b,0x17c0a8,0x17c05b,0x17c0a5,0x17c0b0};
        for(int i=0;i<6;i++)P32(b,at+i*4,table[i]);
        P32(b,p.sections[3].header+8,(uint)(oldSize+24));P32(b,p.opt+140,(uint)(oldSize+24));
        return b;
    }
    [DllImport("imagehlp.dll",CharSet=CharSet.Unicode)]static extern uint MapFileAndCheckSumW(string file,out uint oldSum,out uint checksum);
    public static void SaveCandidate(string file,byte[] b) {
        File.WriteAllBytes(file,b);uint oldSum,checksum;
        if(MapFileAndCheckSumW(file,out oldSum,out checksum)!=0)throw new Exception("PE checksum calculation failed.");
        var p=new PE(b);P32(b,p.opt+64,checksum);File.WriteAllBytes(file,b);
    }
}
