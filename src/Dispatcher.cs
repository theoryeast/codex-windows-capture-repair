// SPDX-License-Identifier: MIT
using System;

// Encoding of native/dispatcher.asm, independently implemented for this project.
// Native CI compares this template and all relocation records with MASM output.
public static class CaptureDispatcher {
    public const int WorkerOffset=91;
    public const int CodeLength=165;
    public static readonly string TemplateHex="4883ec3848894c2430488b01ff500833c933d24c8d05000000004c8b4c243033c048894424204889442428ff15000000004885c07410488bc8ff150000000033c04883c438c3488b4c2430488b01ff5010b8054000804883c438c34883ec3848894c2430b901000000ff15000000008944242885c0780f488b4c243033d24533c0e800000000488b4c2430488b01ff5010837c2428007c06ff150000000033c04883c438c3";
    public static readonly int[] RelocationOffsets={22,45,59,107,130,154};
    public static readonly string[] RelocationNames={"DeferredFrameWorker","__imp_CreateThread","__imp_CloseHandle","__imp_RoInitialize","OriginalFrameArrived","__imp_RoUninitialize"};
    static byte[] Decode(string hex){var b=new byte[hex.Length/2];for(int i=0;i<b.Length;i++)b[i]=Convert.ToByte(hex.Substring(i*2,2),16);return b;}
    public static byte[] Payload(uint rva){
        byte[] code=Decode(TemplateHex);var b=new byte[184];Buffer.BlockCopy(code,0,b,0,code.Length);
        uint[] targets={rva+WorkerOffset,0x176238,0x1761f8,0x176150,0x4247a,0x176158};
        for(int i=0;i<targets.Length;i++){
            int displacement=checked((int)((long)targets[i]-((long)rva+RelocationOffsets[i]+4)));
            Buffer.BlockCopy(BitConverter.GetBytes(displacement),0,b,RelocationOffsets[i],4);
        }
        // UNWIND_INFO: version 1, 4-byte prolog, UWOP_ALLOC_SMALL for 0x38 bytes.
        byte[] unwind=Decode("01040100046200000104010004620000");
        Buffer.BlockCopy(unwind,0,b,168,unwind.Length);return b;
    }
}
