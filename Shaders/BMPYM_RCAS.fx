// ----------------------------------------------------------------//
//                           AMD - RCAS                            //
//                                                                 //
//  FSR - [RCAS] ROBUST CONTRAST ADAPTIVE SHARPENING               //
//      based on AMD FidelityFX FSR 1.0 RCAS implementation        //
// https://github.com/GPUOpen-Effects/FidelityFX-FSR/tree/master   // 
//-----------------------------------------------------------------//


#include "Include/ReShade.fxh"
#include "Include/ReShadeUI.fxh"



//**************************************************//
//                  UNIFORMS                        //
//**************************************************//

uniform float _Sharpness < __UNIFORM_SLIDER_FLOAT1
    ui_min = 0.0; ui_max = 1.0;
    ui_label   = "RCAS Sharpness";
    ui_tooltip = "AMD FidelityFX RCAS sharpening strength (0 = off).";
> = 0.2;



//**************************************************//
//                   TEXTURES                       //
//**************************************************//

texture ColourTex : COLOR;
sampler smColourTex {Texture = ColourTex; SRGBTexture = true;};



//**************************************************//
//                  PASSES                          //
//**************************************************//

float3 RCASPass(float4 position : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
    int2 ip = int2(position.xy);

    float3 b = tex2Doffset(smColourTex, texcoord, int2( 0, -1)).rgb;
    float3 d = tex2Doffset(smColourTex, texcoord, int2(-1,  0)).rgb;
    float3 e = tex2D(smColourTex, texcoord).rgb;
    float3 f = tex2Doffset(smColourTex, texcoord, int2( 1,  0)).rgb;
    float3 h = tex2Doffset(smColourTex, texcoord, int2( 0,  1)).rgb;

    // Luma 
    float bL = b.b * 0.5 + (b.r * 0.5 + b.g);
    float dL = d.b * 0.5 + (d.r * 0.5 + d.g);
    float eL = e.b * 0.5 + (e.r * 0.5 + e.g);
    float fL = f.b * 0.5 + (f.r * 0.5 + f.g);
    float hL = h.b * 0.5 + (h.r * 0.5 + h.g);

    // Noise 
    float nz   = 0.25 * (bL + dL + fL + hL) - eL;
    float lMax = max(max(max(bL, dL), max(fL, hL)), eL);
    float lMin = min(min(min(bL, dL), min(fL, hL)), eL);

    nz = saturate(abs(nz) * rcp(lMax - lMin + 1e-5));
    nz = -0.5 * nz + 1.0;

    // Ring min/max
    float3 mn4 = min(min(b, d), min(f, h));
    float3 mx4 = max(max(b, d), max(f, h));

    // Limiters
    float3 hitMin  = min(mn4, e) * rcp(4.0 * mx4 + 1e-5);
    float3 hitMax  = (1.0 - max(mx4, e)) * rcp(4.0 * mn4 - 4.0 + 1e-5);
    float3 lobeRGB = max(-hitMin, hitMax);

    float lobe = max(lobeRGB.r, max(lobeRGB.g, lobeRGB.b));
    lobe       = clamp(lobe, -0.1875, 0.0);
    lobe      *= _Sharpness;
    lobe      *= nz;

    float rcpL = rcp(4.0 * lobe + 1.0);

    float3 outColor = (b + d + f + h) * lobe + e;
    outColor       *= rcpL;

    return saturate(outColor);
}



//**************************************************//
//                  TECHNIQUES                      //
//**************************************************//

technique FidelityFX_RCAS < 
    ui_label   = "AMD FidelityFX RCAS";
    ui_tooltip =        
        "                                           BMPYM - RCAS                             \n"
        "__________________________________________________________________________________________________\n"
        "\n"
        "This is an implementation of AMD FidelityFX RCAS from FSR 1.0. \n"
        "CAS uses a simplified mechanism to convert local contrast into a variable amount of sharpness.\n"
        "RCAS uses a more exact mechanism, solving for the maximum local sharpness possible before clipping.\n"
        "RCAS also has a built in process to limit sharpening of what it detects as possible noise.\n"
        "\n"
        "___________________________________________________________________________________________________";
>
{
    pass
    {
        VertexShader    = PostProcessVS;
        PixelShader     = RCASPass;
        SRGBWriteEnable = true;
    }
}
