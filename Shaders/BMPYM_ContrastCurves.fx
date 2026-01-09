// ▀█████████▄    ▄▄▄▄███▄▄▄▄      ▄███████▄ ▄██   ▄     ▄▄▄▄███▄▄▄▄   
//   ███    ███ ▄██▀▀▀███▀▀▀██▄   ███    ███ ███   ██▄ ▄██▀▀▀███▀▀▀██▄ 
//   ███    ███ ███   ███   ███   ███    ███ ███▄▄▄███ ███   ███   ███ 
//  ▄███▄▄▄██▀  ███   ███   ███   ███    ███ ▀▀▀▀▀▀███ ███   ███   ███ 
// ▀▀███▀▀▀██▄  ███   ███   ███ ▀█████████▀  ▄██   ███ ███   ███   ███ 
//   ███    ██▄ ███   ███   ███   ███        ███   ███ ███   ███   ███ 
//   ███    ███ ███   ███   ███   ███        ███   ███ ███   ███   ███ 
// ▄█████████▀   ▀█   ███   █▀   ▄████▀       ▀█████▀   ▀█   ███   █▀  
//
//  CONTRAST CURVES
//  ---------------
// 

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

#define PI 3.14159265358979323846f



uniform int Mode < 
    ui_type    = "combo";
    ui_items   = "Luma\0Chroma\0Both\0";
    ui_tooltip = "Choose what to apply contrast to";
> = 0;

uniform int Formula <
    ui_type    = "combo";
    ui_items   = "Power-based\0Adjustable SmoothStep\0Logistic\0";
    ui_tooltip = "The S-Curve formula you want to use (In order of simplest -> complex)";
> = 1;

uniform float Contrast < __UNIFORM_SLIDER_FLOAT1
	ui_min = -1.0; ui_max = 1.0;
	ui_tooltip = "Amount of contrast";
> = 0.65;



// Helper function
float3 Apply_Vector_Curve(float3 v, float curved_mag, float mag) 
{
    float inv_mag = (mag > 1e-5) ? (curved_mag / mag) : 0.0;
    return v * inv_mag;
}


float3 SCurve_Power(float3 x, float strength) 
{
    float mag    = length(x);
    float x0     = saturate(mag);  // [0 : 1]
    float curved = pow(x0, strength);

    return Apply_Vector_Curve(x, curved, mag);
}


float3 SCurve_SmoothStep(float3 x, float contrast) 
{
        float mag = length(x);
        float x0  = saturate(mag);

        float mid   = 0.5;
        float scale = contrast * 0.5;

        float lo = mid - scale;
        float hi = mid + scale;

        float curved = smoothstep(lo, hi, x0);

        return Apply_Vector_Curve(x, curved, mag);
}


float3 SCurve_Logistic(float3 x, float contrast) 
{
    float mag = length(x);
    float x0  = saturate(mag);

    // Logistic steepness
    float k = contrast * 6.0;
    float y = 1.0 / (1.0 + exp(-k * (x0 - 0.5)));

    // Normalize to [0,1]
    float y0 = 1.0 / (1.0 + exp( k * 0.5));
    float y1 = 1.0 / (1.0 + exp(-k * 0.5));

    float curved = (y - y0) / (y1 - y0);

    return Apply_Vector_Curve(x, curved, mag);
}


// ----------------------------------------------------
// ------------------ CURVE PASS ----------------------
// ----------------------------------------------------
float4 ContrastPass(float4 v_pos : SV_POSITION, float2 tex_coord : TEXCOORD) : SV_TARGET 
{
    float4 colour_input   = tex2D(ReShade::BackBuffer, tex_coord);
    float3 luma_coeff     = float3(0.2126, 0.7152, 0.0722); 
    float  contrast_blend = Contrast;
    float3 contrast_input;


    // ----------- Separate Luma & Chroma ---------------
    float luma    = dot(luma_coeff, colour_input.rgb);
    float3 chroma = colour_input.rgb - luma;


    if      (Mode == 0) contrast_input = luma;
    else if (Mode == 1) contrast_input = chroma * 0.5 + 0.5;  // adjust to 0 <=> 1
    else                contrast_input = colour_input.rgb;


    // ----------------- Contrast Formulas ---------------
    if (Formula == 0) contrast_input = SCurve_Power(contrast_input, 0.5);        
    if (Formula == 1) contrast_input = SCurve_SmoothStep(contrast_input, contrast_blend); 
    if (Formula == 2) contrast_input = SCurve_Logistic(contrast_input, contrast_blend);  
    

    // ----------------- Join Luma & Chroma ---------------
    if (Mode == 0) 
    {
        contrast_input   = lerp(luma, contrast_input, contrast_blend);
        colour_input.rgb = contrast_input + chroma;
    }
    else if (Mode == 1) 
    {
        contrast_input   = contrast_input * 2.0 - 1.0;
        float3 colour    = luma + contrast_input;
        colour_input.rgb = lerp(colour_input.rgb, colour, contrast_blend);
    }
    else 
    {
        float3 colour    = contrast_input;
        colour_input.rgb = lerp(colour_input.rgb, colour, contrast_blend); 
    }
    return colour_input;
}


// -------------------------------------
// ----------- TECHNIQUES --------------
// -------------------------------------
technique Contrast 
{
    pass 
    {
        VertexShader = PostProcessVS;
        PixelShader  = ContrastPass;
    }
}