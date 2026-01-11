#include "Include/ReShade.fxh"
#include "Include/ReShadeUI.fxh"
#include "Includes/BMPYM_Common.fxh"



uniform bool u_Mask_UI <
    ui_label   = "Mask UI";
    ui_tooltip = "Mask UI (disable if dithering/crt effects are enabled).";
> = true;



float4 PS_End(float4 position : SV_POSITION, float2 tex_coord : TEXCOORD) : SV_TARGET 
{
    float4 original_colour = tex2D(ReShade::BackBuffer, tex_coord);

    return float4(lerp(tex2D(Common::buffer_sample, tex_coord).rgb, original_colour.rgb, original_colour.a * u_Mask_UI), original_colour.a);
}



technique AcerolaFXEnd <ui_tooltip = "(REQUIRED) Put after all AcerolaFX shaders.";> 
{
    pass 
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_End;
    }
}