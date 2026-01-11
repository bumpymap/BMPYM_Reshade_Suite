#include "Include/ReShade.fxh"
#include "Include/ReShadeUI.fxh"
#include "Includes/BMPYM_Common.fxh"



float4 PS_Start(float4 position : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET 
{
    return tex2D(ReShade::BackBuffer, uv);
}



technique AcerolaFXStart <ui_tooltip = "(REQUIRED) Put before all AcerolaFX shaders.";> 
{
    pass 
    {
        RenderTarget = Common::buffer_sample;

        VertexShader = PostProcessVS;
        PixelShader  = PS_Start;
    }
}