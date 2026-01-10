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
    ui_items   = "Power-based\0Adjustable SmoothStep\0Logistic\0Hermite\0Perceptual (Reinhard)\0ACES\0Catmull-Rom\0Exponential\0Uncharted2\0Parametric Sigmoid\0";
    ui_tooltip = "The S-Curve formula you want to use (In order of simplest -> complex)";
> = 0;

uniform float Contrast < __UNIFORM_SLIDER_FLOAT1
	ui_min = -1.0; ui_max = 1.0;
	ui_tooltip = "Amount of contrast";
> = 0.0;



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


float3 SCurve_Hermite(float3 x, float contrast) 
{
    float mag = length(x);
    float x0  = saturate(mag);
    
    float t = x0;
    float strength = contrast * 2.0;
    
    // Split at midpoint with controllable transition
    float curved;
    if (t < 0.5) curved = 0.5 * pow(2.0 * t, 1.0 + strength);
    else         curved = 1.0 - 0.5 * pow(2.0 * (1.0 - t), 1.0 + strength);
    
    return Apply_Vector_Curve(x, curved, mag);
}


float3 SCurve_Perceptual(float3 x, float contrast) 
{
    float mag = length(x);
    float x0  = saturate(mag);
    
    // Toe and shoulder control
    float toe      = 0.2 * contrast;
    float shoulder = 0.8 + (0.2 * (1.0 - contrast));
    
    float curved;
    if (x0 < toe) 
    {
        curved = (x0 * x0) / (2.0 * toe);
    } 
    else if (x0 > shoulder) 
    {
        float excess = x0 - shoulder;
        curved       = shoulder + excess / (1.0 + excess);
    } 
    else 
    {
        curved = x0;
    }
    
    return Apply_Vector_Curve(x, curved, mag);
}


float3 SCurve_ACES(float3 x, float contrast) 
{
    float mag = length(x);
    float x0  = saturate(mag);
    
    // ACES approximation with contrast control
    float a = 2.51 * contrast;
    float b = 0.03;
    float c = 2.43 * contrast;
    float d = 0.59;
    float e = 0.14;
    
    float curved = saturate((x0 * (a * x0 + b)) / (x0 * (c * x0 + d) + e));
    
    return Apply_Vector_Curve(x, curved, mag);
}


float3 SCurve_CatmullRom(float3 x, float contrast) 
{
    float mag = length(x);
    float x0  = saturate(mag);
    
    // Control points based on contrast
    float p0 = 0.0;
    float p1 = 0.5 - contrast * 0.2;
    float p2 = 0.5 + contrast * 0.2;
    float p3 = 1.0;
    
    float t  = x0;
    float t2 = t * t;
    float t3 = t2 * t;
    
    float curved = 0.5 * (
        (2.0 * p1) +
        (-p0 + p2) * t +
        (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
        (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
    );
    
    return Apply_Vector_Curve(x, curved, mag);
}


float3 SCurve_Exponential(float3 x, float contrast) 
{
    float mag = length(x);
    float x0  = saturate(mag);
    
    float k = contrast * 3.0;
    
    // Toe (shadows)
    float toe = 1.0 - exp(-k * x0);
    
    // Shoulder (highlights)
    float shoulder = exp(-k * (1.0 - x0));
    
    // Blend based on input value
    float curved = lerp(toe, 1.0 - shoulder, x0);
    
    return Apply_Vector_Curve(x, curved, mag);
}


float3 SCurve_Uncharted2(float3 x, float contrast) 
{
    float mag = length(x);
    float x0  = saturate(mag);
    
    float A = 0.15 * contrast;
    float B = 0.50;
    float C = 0.10;
    float D = 0.20 * contrast;
    float E = 0.02;
    float F = 0.30;
    
    float curved = ((x0 * (A * x0 + C * B) + D * E) / (x0 * (A * x0 + B) + D * F)) - E / F;
    curved       = saturate(curved);
    
    return Apply_Vector_Curve(x, curved, mag);
}


float3 SCurve_Parametric(float3 x, float contrast) 
{
    float mag = length(x);
    float x0  = saturate(mag);
    
    float slope             = 1.0 + contrast * 4.0;
    float toe_strength      = 0.5;
    float shoulder_strength = 0.5;
    
    float curved;
    if (x0 < 0.5) curved = pow(2.0 * x0, slope * toe_strength) * 0.5;
    else          curved = 1.0 - pow(2.0 * (1.0 - x0), slope * shoulder_strength) * 0.5;
    
    return Apply_Vector_Curve(x, curved, mag);
}


//***********************************//
//           CURVE PASS              //
//***********************************//
float4 ContrastPass(float4 v_pos : SV_POSITION, float2 tex_coord : TEXCOORD) : SV_TARGET 
{
    float4 colour_input   = tex2D(ReShade::BackBuffer, tex_coord);
    float3 luma_coeff     = float3(0.2126, 0.7152, 0.0722); 
    float  contrast_blend = Contrast;
    float3 contrast_input;


    // ----------- Separate Luma & Chroma ---------------
    float  luma   = dot(luma_coeff, colour_input.rgb);
    float3 chroma = colour_input.rgb - luma;


    if      (Mode == 0) contrast_input = luma;
    else if (Mode == 1) contrast_input = chroma * 0.5 + 0.5;  // adjust to 0 <=> 1
    else                contrast_input = colour_input.rgb;


    // ----------------- Contrast Formulas ---------------
    if (Formula == 0) contrast_input = SCurve_Power(contrast_input, 0.5);        
    if (Formula == 1) contrast_input = SCurve_SmoothStep(contrast_input, contrast_blend); 
    if (Formula == 2) contrast_input = SCurve_Logistic(contrast_input, contrast_blend);  
    if (Formula == 3) contrast_input = SCurve_Hermite(contrast_input, contrast_blend); 
    if (Formula == 4) contrast_input = SCurve_Perceptual(contrast_input, contrast_blend); 
    if (Formula == 5) contrast_input = SCurve_ACES(contrast_input, contrast_blend); 
    if (Formula == 6) contrast_input = SCurve_CatmullRom(contrast_input, contrast_blend); 
    if (Formula == 7) contrast_input = SCurve_Exponential(contrast_input, contrast_blend); 
    if (Formula == 8) contrast_input = SCurve_Uncharted2(contrast_input, contrast_blend); 
    if (Formula == 9) contrast_input = SCurve_Parametric(contrast_input, contrast_blend); 

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


//***********************************//
//           TECHNIQUES              //
//***********************************//
technique Contrast 
{
    pass 
    {
        VertexShader = PostProcessVS;
        PixelShader  = ContrastPass;
    }
}