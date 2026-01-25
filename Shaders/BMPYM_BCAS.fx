// ----------------------------------------------------------------//
//                          Better CAS                             //
//                                                                 //
//  FSR - [CAS] CONTRAST ADAPTIVE SHARPENING                       //
//      based on AMD FidelityFX CAS implementation                 //
//  https://github.com/GPUOpen-Effects/FidelityFX-CAS/blob/master  // 
//-----------------------------------------------------------------//

//--------------------------------//
#include "Include/BMPYM_Common.fxh"
#include "Include/ReShadeUI.fxh"
//--------------------------------//



//**************************************************//
//                  UNIFORMS                        //
//**************************************************//

uniform float _Contrast < __UNIFORM_DRAG_FLOAT1
    ui_min = 0.0; ui_max = 1.0;
	ui_label   = "Contrast Adaptation";
	ui_tooltip = "Adjusts the range the shader adapts to high contrast (0 is not all the way off).  Higher values = more high contrast sharpening";
> = 0.0;

uniform float _Sharpening < __UNIFORM_DRAG_FLOAT1
    ui_min = 0.0; ui_max = 1.0;
	ui_label   = "Sharpening intensity";
	ui_tooltip = "Adjusts sharpening intensity by averaging the original pixels to the sharpened result. 1.0 is the unmodified default";
> = 1.0;

uniform float _DepthEdgeStrength < __UNIFORM_DRAG_FLOAT1
    ui_min = 0.0; ui_max = 1.0;
	ui_label    = "Depth Edge Preservation";
	ui_tooltip  = "How much to reduce sharpening at edges. Higher = less sharpening at edges to prevent halos";
    ui_category = "Depth Awareness";
> = 0.7;

uniform float _DepthFadeStart < __UNIFORM_DRAG_FLOAT1
    ui_min = 0.0; ui_max = 1.0;
	ui_label    = "Depth Fade Start";
	ui_tooltip  = "Distance where sharpening begins to fade (0 = camera, 1 = far plane). Use to reduce distant noise sharpening";
    ui_category = "Depth Awareness";
> = 0.5;

uniform float _DepthFadeEnd < __UNIFORM_DRAG_FLOAT1
    ui_min = 0.0; ui_max = 1.0;
	ui_label    = "Depth Fade End";
	ui_tooltip  = "Distance where sharpening fully fades out. Should be > Fade Start";
    ui_category = "Depth Awareness";
> = 1.0;

uniform float _EdgeSensitivity < __UNIFORM_DRAG_FLOAT1
    ui_min = 0.001; ui_max = 0.1;
	ui_label    = "Edge Sensitivity";
	ui_tooltip  = "Threshold for detecting depth edges. Lower = more sensitive to small depth changes";
    ui_category = "Depth Awareness";
> = 0.02;

uniform bool _ShowDepthEdges < 
	ui_label    = "Show Depth Edges (Debug)";
	ui_tooltip  = "Visualize detected depth edges in red";
    ui_category = "Depth Awareness";
> = false;



//**************************************************//
//                   TEXTURES                       //
//**************************************************//

texture tColourTex : COLOR;
texture tDepthTex  : DEPTH;

sampler smColourTex { Texture = tColourTex; SRGBTexture = true; };
sampler smDepthTex  { Texture = tDepthTex; };



//**************************************************//
//                  FUNCTIONS                       //
//**************************************************//

float GetLinearDepth(float2 texcoord)
{
    float depth = tex2D(smDepthTex, texcoord).x;
    return ReShade::GetLinearizedDepth(depth);
}


float DetectDepthEdge(float2 texcoord)
{
    float d0 = GetLinearDepth(texcoord + float2(-1, -1) * BUFFER_PIXEL_SIZE);
    float d1 = GetLinearDepth(texcoord + float2( 0, -1) * BUFFER_PIXEL_SIZE);
    float d2 = GetLinearDepth(texcoord + float2( 1, -1) * BUFFER_PIXEL_SIZE);
    float d3 = GetLinearDepth(texcoord + float2(-1,  0) * BUFFER_PIXEL_SIZE);
    float d4 = GetLinearDepth(texcoord); 
    float d5 = GetLinearDepth(texcoord + float2( 1,  0) * BUFFER_PIXEL_SIZE);
    float d6 = GetLinearDepth(texcoord + float2(-1,  1) * BUFFER_PIXEL_SIZE);
    float d7 = GetLinearDepth(texcoord + float2( 0,  1) * BUFFER_PIXEL_SIZE);
    float d8 = GetLinearDepth(texcoord + float2( 1,  1) * BUFFER_PIXEL_SIZE);
    
    float sobelX = (d2 + 2.0 * d5 + d8) - (d0 + 2.0 * d3 + d6);
    float sobelY = (d6 + 2.0 * d7 + d8) - (d0 + 2.0 * d1 + d2);
    
    float edgeMagnitude  = sqrt(sobelX * sobelX + sobelY * sobelY);
    float normalizedEdge = edgeMagnitude / (d4 + 0.001);
    
    return saturate(normalizedEdge / _EdgeSensitivity);
}


float GetDepthFade(float2 texcoord)
{
    float depth = GetLinearDepth(texcoord);
    
    float fadeRange = _DepthFadeEnd - _DepthFadeStart;
    if (fadeRange < 0.001) return 1.0; 
    
    float fade = 1.0 - saturate((depth - _DepthFadeStart) / fadeRange);
    
    return fade * fade * (3.0 - 2.0 * fade);
}


float GetDepthWeight(float2 texcoord)
{
    float edgeStrength = DetectDepthEdge(texcoord);
    float edgeWeight   = lerp(1.0, 1.0 - edgeStrength, _DepthEdgeStrength);
    float fadeWeight   = GetDepthFade(texcoord);
    
    return edgeWeight * fadeWeight;
}



//**************************************************//
//                  PASSES                          //
//**************************************************//

float3 PS_CASPass(float4 position : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
    float depthWeight = GetDepthWeight(texcoord);
    
    if (_ShowDepthEdges)
    {
        float edge       = DetectDepthEdge(texcoord);
        float3 baseColor = tex2D(smColourTex, texcoord).rgb;

        return lerp(baseColor, float3(1, 0, 0), edge * 0.7);
    }

    float3 b = tex2Doffset(smColourTex, texcoord, int2(0, -1)).rgb;
	float3 d = tex2Doffset(smColourTex, texcoord, int2(-1, 0)).rgb;

    float4 red_efhi   = tex2DgatherR(smColourTex, texcoord + 0.5 * BUFFER_PIXEL_SIZE);
	float4 green_efhi = tex2DgatherG(smColourTex, texcoord + 0.5 * BUFFER_PIXEL_SIZE);
    float4 blue_efhi  = tex2DgatherB(smColourTex, texcoord + 0.5 * BUFFER_PIXEL_SIZE);

	float3 e = float3(red_efhi.w, red_efhi.w, red_efhi.w);
	float3 f = float3(red_efhi.z, red_efhi.z, red_efhi.z);
	float3 h = float3(red_efhi.x, red_efhi.x, red_efhi.x);
	float3 i = float3(red_efhi.y, red_efhi.y, red_efhi.y);
	
	e.g = green_efhi.w;
	f.g = green_efhi.z;
	h.g = green_efhi.x;
	i.g = green_efhi.y;
	
	e.b = blue_efhi.w;
	f.b = blue_efhi.z;
	h.b = blue_efhi.x;
	i.b = blue_efhi.y;

	float3 g = tex2Doffset(smColourTex, texcoord, int2(-1, 1)).rgb; 
	float3 a = tex2Doffset(smColourTex, texcoord, int2(-1, -1)).rgb;
	float3 c = tex2Doffset(smColourTex, texcoord, int2(1, -1)).rgb;

	float3 mnRGB  = min(min(min(d, e), min(f, b)), h);
	float3 mnRGB2 = min(mnRGB, min(min(a, c), min(g, i)));
	mnRGB        += mnRGB2;

	float3 mxRGB  = max(max(max(d, e), max(f, b)), h);
	float3 mxRGB2 = max(mxRGB, max(max(a, c), max(g, i)));
	mxRGB        += mxRGB2;

	float3 rcpMRGB = rcp(mxRGB);
	float3 ampRGB  = saturate(min(mnRGB, 2.0 - mxRGB) * rcpMRGB);	
	
	ampRGB = rsqrt(ampRGB);
	
	float peak  = -3.0 * _Contrast + 8.0;
	float3 wRGB = -rcp(ampRGB * peak);

	float3 rcpWeightRGB = rcp(4.0 * wRGB + 1.0);

	float3 window   = (b + d) + (f + h);
	float3 outColor = saturate((window * wRGB + e) * rcpWeightRGB);
	
    float sharpenFactor = _Sharpening * depthWeight;

	return lerp(e, outColor, sharpenFactor);
}



//**************************************************//
//                  TECHNIQUES                      //
//**************************************************//

technique BMPYM_BCAS < 
    ui_label   = "Better CAS";
    ui_tooltip =        
        "                     BMPYM - B(etter)CAS                      \n"
        "_____________________________________________________________\n"
        "\n"
        "This is an improved implementation of AMD FidelityFX CAS.    \n"
        "It is essentially CAS with added depth awareness.            \n"
        "\n"
        "_____________________________________________________________";
>
{
    pass
    {
        VertexShader    = PostProcessVS;
        PixelShader     = PS_CASPass;
        SRGBWriteEnable = true; 
    }
}
