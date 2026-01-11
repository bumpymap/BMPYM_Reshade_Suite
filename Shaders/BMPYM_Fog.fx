// ▀█████████▄    ▄▄▄▄███▄▄▄▄      ▄███████▄ ▄██   ▄     ▄▄▄▄███▄▄▄▄   
//   ███    ███ ▄██▀▀▀███▀▀▀██▄   ███    ███ ███   ██▄ ▄██▀▀▀███▀▀▀██▄ 
//   ███    ███ ███   ███   ███   ███    ███ ███▄▄▄███ ███   ███   ███ 
//  ▄███▄▄▄██▀  ███   ███   ███   ███    ███ ▀▀▀▀▀▀███ ███   ███   ███ 
// ▀▀███▀▀▀██▄  ███   ███   ███ ▀█████████▀  ▄██   ███ ███   ███   ███ 
//   ███    ██▄ ███   ███   ███   ███        ███   ███ ███   ███   ███ 
//   ███    ███ ███   ███   ███   ███        ███   ███ ███   ███   ███ 
// ▄█████████▀   ▀█   ███   █▀   ▄████▀       ▀█████▀   ▀█   ███   █▀  
//
//  FOG
//  ---------------
// 

#include "Include/ReShade.fxh"
#include "Include/ReShadeUI.fxh"


uniform float3 Fog_Colour <
    ui_min = 0.0f; ui_max = 1.0f;
    ui_label   = "Fog Colour";
    ui_type    = "color";
    ui_tooltip = "Set fog colour";
> = float3(0.6f, 0.6f, 0.6f);

uniform float Density <
    ui_min = 0.0001f; ui_max = 0.005f;
    ui_label   = "Fog Density";
    ui_type    = "slider";
    ui_tooltip = "Adjust density of the fog";
> = 0.002f;

uniform float Z_Projection <
    ui_category_closed = true;
    ui_category        = "Advanced settings";
    ui_min = 0.0f; ui_max = 5000.0f;
    ui_label   = "Camera Z Projection";
    ui_type    = "slider";
    ui_tooltip = "Adjust Camera Z Projection (depth of the camera frustum).";
> = 1000.0f;


texture2D buffer_tex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
texture2D render_tex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16f; };
sampler2D fog_sample { Texture = render_tex; MagFilter = POINT; MinFilter = POINT; MipFilter = POINT; };


float3 Get_Fog_Factor(float3 colour, float dist) 
{
    float fog_amount = 1.0f - exp(-dist * Density);
    
    return lerp(colour, Fog_Colour, fog_amount);
}


//**************************************************//
//                  PASSES                          //
//**************************************************//

float4 PS_End_Pass(float4 v_pos : SV_POSITION, float2 tex_coord : TEXCOORD) : SV_TARGET 
{
    return tex2D(fog_sample, tex_coord).rgba;
}


float4 PS_Fog_Pass(float4 v_pos : SV_POSITION, float2 tex_coord : TEXCOORD) : SV_TARGET
{
    float4 colour_input = tex2D(ReShade::BackBuffer, tex_coord).rgba;
    
    float depth     = ReShade::GetLinearizedDepth(tex_coord);
    float view_dist = depth * Z_Projection;

    float3 col = Get_Fog_Factor(colour_input.rgb, view_dist);

    return float4(col, colour_input.a);
}


//**************************************************//
//                  TECHNIQUES                      //
//**************************************************//

technique Fog <ui_label = "Fog"; ui_tooltip = "(LDR) Applies a color to distant pixels to exaggerate distance."; >  
{
    pass 
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_Fog_Pass;
    }
}