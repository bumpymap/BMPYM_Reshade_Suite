// -----------------------------------------------------------//
//                          GAMMA                             //
//                                                            //
// Simple gamma adjustment                                    //
//------------------------------------------------------------//

//--------------------------------//
#include "Include/BMPYM_Common.fxh"
#include "Include/ReShadeUI.fxh"
//--------------------------------//


//**************************************************//
//                  UNIFORMS                        //
//**************************************************//

uniform float _Gamma < __UNIFORM_SLIDER_FLOAT1
    ui_min = 0.0f; ui_max = 5.0f;
    ui_label   = "Gamma";
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

technique Gamma < ui_label = "Gamma"; ui_tooltip = "Adjusts the gamma correction of the screen"; > 
{
    pass 
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_Gamma;
    }
}