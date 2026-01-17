// -----------------------------------------------------------//
//                          GAMMA                             //
//                                                            //
// Simple gamma adjustment                                    //
//------------------------------------------------------------//

#include "Include/ReShade.fxh"
#include "Include/ReShadeUI.fxh"



//**************************************************//
//                  UNIFORMS                        //
//**************************************************//

uniform float _Gamma <
    ui_min = 0.0f; ui_max = 5.0f;
    ui_label   = "Gamma";
    ui_type    = "drag";
    ui_tooltip = "Adjust gamma correction";
> = 1.0f;


//**************************************************//
//                  PASSES                          //
//**************************************************//

float4 PS_Gamma(float4 position : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
    float4 sColour = saturate(tex2D(ReShade::BackBuffer, texcoord).rgba);

    return saturate(pow(abs(sColour), _Gamma));
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