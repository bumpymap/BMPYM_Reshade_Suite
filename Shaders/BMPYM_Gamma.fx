// -----------------------------------------------------------//
//                          GAMMA                             //
// written by Mitch J. - https://github.com/bumpymap          //
//                                                            //
// Simple gamme adjustment                                    //
//------------------------------------------------------------//

#include "Include/ReShade.fxh"
#include "Include/ReShadeUI.fxh"


uniform float u_gamma <
    ui_min = 0.0f; ui_max = 5.0f;
    ui_label   = "Gamma";
    ui_type    = "drag";
    ui_tooltip = "Adjust gamma correction";
> = 1.0f;


//**************************************************//
//                  PASSES                          //
//**************************************************//

float4 PS_Gamma(float4 v_pos : SV_POSITION, float2 tex_coord : TEXCOORD) : SV_TARGET
{
    float4 colour_input = saturate(tex2D(ReShade::BackBuffer, tex_coord).rgba);

    return saturate(pow(abs(colour_input), u_gamma));
}


//**************************************************//
//                  TECHNIQUES                      //
//**************************************************//

technique Gamma < ui_label = "Gamma"; ui_tooltip = "(LDR) Adjusts the gamma correction of the screen"; > 
{
    pass 
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_Gamma;
    }
}