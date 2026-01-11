// ▀█████████▄    ▄▄▄▄███▄▄▄▄      ▄███████▄ ▄██   ▄     ▄▄▄▄███▄▄▄▄   
//   ███    ███ ▄██▀▀▀███▀▀▀██▄   ███    ███ ███   ██▄ ▄██▀▀▀███▀▀▀██▄ 
//   ███    ███ ███   ███   ███   ███    ███ ███▄▄▄███ ███   ███   ███ 
//  ▄███▄▄▄██▀  ███   ███   ███   ███    ███ ▀▀▀▀▀▀███ ███   ███   ███ 
// ▀▀███▀▀▀██▄  ███   ███   ███ ▀█████████▀  ▄██   ███ ███   ███   ███ 
//   ███    ██▄ ███   ███   ███   ███        ███   ███ ███   ███   ███ 
//   ███    ███ ███   ███   ███   ███        ███   ███ ███   ███   ███ 
// ▄█████████▀   ▀█   ███   █▀   ▄████▀       ▀█████▀   ▀█   ███   █▀  
//
//  COLOUR CORRECTION
//  =================

#include "Include/ReShade.fxh"
#include "Include/ReShadeUI.fxh"
#include "Include/BMPYM_Common.fxh"


//**************************************************//
//                  UNIFORMS                        //
//**************************************************//

uniform bool u_HDR <
    ui_label   = "HDR";
    ui_tooltip = "Enable HDR (Color values can exceed 1).";
> = true;

uniform float u_Exposure <
    ui_min = 0.0f; ui_max = 10.0f;
    ui_label   = "Exposure";
    ui_type    = "drag";
    ui_tooltip = "Adjust camera exposure.";
> = 1.0f;

uniform float u_Temperature <
    ui_min = -1.0f; ui_max = 1.0f;
    ui_label   = "Temperature";
    ui_type    = "drag";
    ui_tooltip = "Adjust white balancing temperature";
> = 0.0f;

uniform float u_Tint <
    ui_min = -1.0f; ui_max = 1.0f;
    ui_label   = "Tint";
    ui_type    = "drag";
    ui_tooltip = "Adjust white balance color tint";
> = 0.0f;

uniform float3 u_Contrast <
    ui_min = 0.0f; ui_max = 5.0f;
    ui_label   = "Contrast";
    ui_type    = "drag";
    ui_tooltip = "Adjust contrast";
> = 1.0f;

uniform float3 u_Linear_MidPoint <
    ui_min = 0.0f; ui_max = 5.0f;
    ui_label   = "Linear Mid Point";
    ui_type    = "drag";
    ui_tooltip = "Adjust the midpoint value between black and fully saturated for contrast";
> = 0.5f;

uniform float3 u_Brightness <
    ui_min = -5.0f; ui_max = 5.0f;
    ui_label   = "Brightness";
    ui_type    = "drag";
    ui_tooltip = "Adjust brightness of each color channel";
> = float3(0.0, 0.0, 0.0);

uniform float3 u_Color_Filter <
    ui_min = 0.0f; ui_max = 1.0f;
    ui_label   = "Color Filter";
    ui_type    = "color";
    ui_tooltip = "Set color filter (white for no change)";
> = float3(1.0, 1.0, 1.0);

uniform float u_Filter_Intensity <
    ui_min = 0.0f; ui_max = 10.0f;
    ui_label   = "Color Filter Intensity (HDR)";
    ui_type    = "drag";
    ui_tooltip = "Adjust the intensity of the color filter";
> = 1.0f;

uniform float3 u_Saturation <
    ui_min = 0.0f; ui_max = 5.0f;
    ui_label   = "Saturation";
    ui_type    = "drag";
    ui_tooltip = "Adjust saturation";
> = 1.0f;


//**************************************************//
//                  PASSES                          //
//**************************************************//

float4 PS_ColorCorrect(float4 v_pos : SV_POSITION, float2 tex_coord : TEXCOORD) : SV_TARGET 
{
    float4 col   = tex2D(ReShade::BackBuffer, tex_coord).rgba;
    float UIMask = 1.0f - col.a;

    float3 output = col.rgb;
    if (!u_HDR) output = saturate(output);

    output *= u_Exposure;
    if (!u_HDR) output = saturate(output);

    output = Common::WhiteBalance(output.rgb, u_Temperature, u_Tint);
    output = u_HDR ? max(0.0f, output) : saturate(output);

    output = u_Contrast * (output - u_Linear_MidPoint) + u_Linear_MidPoint + u_Brightness;
    output = u_HDR ? max(0.0f, output) : saturate(output);

    output *= (u_Color_Filter * u_Filter_Intensity);
    if (!u_HDR) output = saturate(output);
    
    output = lerp(Common::Luminance(output), output, u_Saturation);
    if (!u_HDR) output = saturate(output);

    return float4(output, col.a);
}


//**************************************************//
//                  TECHNIQUES                      //
//**************************************************//

technique ColorCorrection  <ui_label = "Color Correct"; ui_tooltip = "(HDR/LDR) A suite of color correction effects."; >  
{
    pass ColorCorrect 
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_ColorCorrect;
    }
}
