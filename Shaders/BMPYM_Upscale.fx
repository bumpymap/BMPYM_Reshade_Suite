// -----------------------------------------------------------//
//                         UPSCALE                            //
// written by Mitch J. - https://github.com/bumpymap          //
//                                                            //
// Upscaling solution - edge-adaptive interpolation,          //
// perceptual sharpening, and anti-aliasing                   //
//------------------------------------------------------------//


#include "Include/ReShade.fxh"
#include "Include/ReShadeUI.fxh"


//**************************************************//
//                  UNIFORMS                        //
//**************************************************//


uniform float u_Upscale_Strength < 
    ui_min = 0.0; ui_max = 2.0;
    ui_type    = "slider";
    ui_label   = "Upscale Strength";
    ui_tooltip = "Overall strength of the upscaling effect";
> = 1.0;

uniform float u_Edge_Threshold <
    ui_min = 0.0; ui_max = 1.0;
    ui_type    = "slider";
    ui_label   = "Edge Detection Threshold";
    ui_tooltip = "Lower values detect more edges";
> = 0.15;

uniform float u_Sharpen_Strength <
    ui_min = 0.0; ui_max = 2.0;
    ui_type    = "slider";
    ui_label   = "Sharpening Strength";
    ui_tooltip = "Adaptive sharpening strength";
> = 0.5;

uniform float u_Denoise_Strength <
    ui_min = 0.0; ui_max = 1.0;
    ui_type    = "slider";
    ui_label   = "Denoise Strength";
    ui_tooltip = "Reduces noise and artifacts";
> = 0.3;

uniform int u_Upscale_Method <
    ui_type  = "combo";
    ui_items = "Lanczos\0Bicubic (Mitchell-Netravali)\0Edge-Adaptive\0Hybrid\0";
    ui_label = "Upscaling Method";
> = 3;


//**************************************************//
//                  FUNCTIONS                       //
//**************************************************//

// Lanczos kernel
float Lanczos(float x, float a)
{
    if (abs(x) < 1e-6) return 1.0;
    if (abs(x) >= a)   return 0.0;
    
    float pi_x = 3.14159265359 * x;

    return (a * sin(pi_x) * sin(pi_x / a)) / (pi_x * pi_x);
}


// Mitchell-Netravali bicubic filter
float Mitchell_Netravali(float x)
{
    float B = 1.0 / 3.0;
    float C = 1.0 / 3.0;
    
    x = abs(x);
    
    if (x < 1.0)
        return ((12.0 - 9.0 * B - 6.0 * C) * x * x * x + 
                (-18.0 + 12.0 * B + 6.0 * C) * x * x + 
                (6.0 - 2.0 * B)) / 6.0;
    else if (x < 2.0)
        return ((-B - 6.0 * C) * x * x * x + 
                (6.0 * B + 30.0 * C) * x * x + 
                (-12.0 * B - 48.0 * C) * x + 
                (8.0 * B + 24.0 * C)) / 6.0;
    else
        return 0.0;
}

// Edge detection using Sobel operator
float Detect_Edge(float2 tex_coord)
{
    float2 px = ReShade::PixelSize;
    
    float3 tl = tex2D(ReShade::BackBuffer, tex_coord + float2(-px.x, -px.y)).rgb;
    float3 t  = tex2D(ReShade::BackBuffer, tex_coord + float2(0.0, -px.y)).rgb;
    float3 tr = tex2D(ReShade::BackBuffer, tex_coord + float2(px.x, -px.y)).rgb;
    float3 l  = tex2D(ReShade::BackBuffer, tex_coord + float2(-px.x, 0.0)).rgb;
    float3 r  = tex2D(ReShade::BackBuffer, tex_coord + float2(px.x, 0.0)).rgb;
    float3 bl = tex2D(ReShade::BackBuffer, tex_coord + float2(-px.x, px.y)).rgb;
    float3 b  = tex2D(ReShade::BackBuffer, tex_coord + float2(0.0, px.y)).rgb;
    float3 br = tex2D(ReShade::BackBuffer, tex_coord + float2(px.x, px.y)).rgb;
    
    float3 sobelX = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
    float3 sobelY = -tl - 2.0 * t - tr + bl + 2.0 * b + br;
    
    return length(sobelX) + length(sobelY);
}


float3 Lanczos_Upscale(float2 tex_coord)
{
    float2 px          = ReShade::PixelSize;
    float2 coord_hg    = tex_coord * ReShade::ScreenSize;
    float2 coord_floor = floor(coord_hg - 0.5) + 0.5;
    float2 f           = coord_hg - coord_floor;
    
    float3 color     = 0.0;
    float weight_sum = 0.0;
    
    const int radius = 2;
    
    [unroll]
    for (int y = -radius + 1; y <= radius; y++)
    {
        [unroll]
        for (int x = -radius + 1; x <= radius; x++)
        {
            float2 offset       = float2(x, y);
            float2 sample_coord = (coord_floor + offset) * px;
            
            float wx = Lanczos(f.x - offset.x, radius);
            float wy = Lanczos(f.y - offset.y, radius);
            float w  = wx * wy;
            
            color      += tex2Dlod(ReShade::BackBuffer, float4(sample_coord, 0, 0)).rgb * w;
            weight_sum += w;
        }
    }
    
    return color / max(weight_sum, 1e-6);
}


float3 Bicubic_Upscale(float2 tex_coord)
{
    float2 px          = ReShade::PixelSize;
    float2 coord_hg    = tex_coord * ReShade::ScreenSize;
    float2 coord_floor = floor(coord_hg - 0.5) + 0.5;
    float2 f           = coord_hg - coord_floor;
    
    float3 color = 0.0;
    float weight_sum = 0.0;
    
    [unroll]
    for (int y = -1; y <= 2; y++)
    {
        [unroll]
        for (int x = -1; x <= 2; x++)
        {
            float2 offset       = float2(x, y);
            float2 sample_coord = (coord_floor + offset) * px;
            
            float wx = Mitchell_Netravali(f.x - offset.x);
            float wy = Mitchell_Netravali(f.y - offset.y);
            float w  = wx * wy;
            
            color      += tex2Dlod(ReShade::BackBuffer, float4(sample_coord, 0, 0)).rgb * w;
            weight_sum += w;
        }
    }
    
    return color / max(weight_sum, 1e-6);
}


float3 Edge_Adaptive_Upscale(float2 tex_coord)
{
    float2 px = ReShade::PixelSize;
    float edge_strength = Detect_Edge(tex_coord);
    
    // On edges, use directional filtering
    if (edge_strength > u_Edge_Threshold)
    {
        // Sample in a cross pattern to find edge direction
        float3 samples[4];
        samples[0] = tex2D(ReShade::BackBuffer, tex_coord + float2(-px.x, 0.0)).rgb;
        samples[1] = tex2D(ReShade::BackBuffer, tex_coord + float2(px.x, 0.0)).rgb;
        samples[2] = tex2D(ReShade::BackBuffer, tex_coord + float2(0.0, -px.y)).rgb;
        samples[3] = tex2D(ReShade::BackBuffer, tex_coord + float2(0.0, px.y)).rgb;
        
        float3 center = tex2D(ReShade::BackBuffer, tex_coord).rgb;
        
        // Find best matching direction
        float weights[4];
        weights[0] = 1.0 / (1.0 + length(samples[0] - center));
        weights[1] = 1.0 / (1.0 + length(samples[1] - center));
        weights[2] = 1.0 / (1.0 + length(samples[2] - center));
        weights[3] = 1.0 / (1.0 + length(samples[3] - center));
        
        float total_weight = weights[0] + weights[1] + weights[2] + weights[3];
        
        return (samples[0] * weights[0] + samples[1] * weights[1] + 
                samples[2] * weights[2] + samples[3] * weights[3]) / total_weight;
    }
    else
    {
        // In smooth areas, use bicubic
        return Bicubic_Upscale(tex_coord);
    }
}

float3 Hybrid_Upscale(float2 tex_coord)
{
    float edge_strength = Detect_Edge(tex_coord);
    
    float3 lanczos = Lanczos_Upscale(tex_coord);
    float3 edge_adaptive = Edge_Adaptive_Upscale(tex_coord);
    
    // Blend based on edge strength
    float blend = saturate(edge_strength / u_Edge_Threshold);
    return lerp(lanczos, edge_adaptive, blend);
}


float3 Adaptive_Sharpen(float2 tex_coord, float3 color)
{
    float2 px = ReShade::PixelSize;
    
    // Sample neighbors
    float3 a = tex2D(ReShade::BackBuffer, tex_coord + float2(0.0, -px.y)).rgb;
    float3 b = tex2D(ReShade::BackBuffer, tex_coord + float2(-px.x, 0.0)).rgb;
    float3 d = tex2D(ReShade::BackBuffer, tex_coord + float2(px.x, 0.0)).rgb;
    float3 e = tex2D(ReShade::BackBuffer, tex_coord + float2(0.0, px.y)).rgb;
    
    // Find local min and max
    float3 min_rgb = min(min(min(a, b), min(d, e)), color);
    float3 max_rgb = max(max(max(a, b), max(d, e)), color);
    
    // Calculate sharpening amount based on local contrast
    float3 contrast = max_rgb - min_rgb;
    float3 weight = -rcp(contrast * 5.0 + 1.0);
    
    // Apply sharpening
    float3 sharp = (a + b + d + e) * weight + color;
    sharp = clamp(sharp, min_rgb, max_rgb);
    
    return lerp(color, sharp, u_Sharpen_Strength);
}


//**************************************************//
//                  PASSES                          //
//**************************************************//

float3 PS_BMPYM_Upscale(float4 pos : SV_Position, float2 tex_coord : TEX_COORD) : SV_Target
{
    float3 upscaled;
    
    switch(u_Upscale_Method)
    {
        case 0:  upscaled = Lanczos_Upscale(tex_coord); break;
        case 1:  upscaled = Bicubic_Upscale(tex_coord); break;
        case 2:  upscaled = Edge_Adaptive_Upscale(tex_coord); break;
        default: upscaled = Hybrid_Upscale(tex_coord); break;
    }
    
    // Apply adaptive sharpening
    float3 sharpened = Adaptive_Sharpen(tex_coord, upscaled);
    
    // Denoise by blending with bilateral filtered result
    if (u_Denoise_Strength > 0.0)
    {
        float3 center    = sharpened;
        float3 denoised  = 0.0;
        float weight_sum = 0.0;
        
        float2 px = ReShade::PixelSize;
        
        [unroll]
        for (int y = -1; y <= 1; y++)
        {
            [unroll]
            for (int x = -1; x <= 1; x++)
            {
                float2 offset       = float2(x, y) * px;
                float3 sample_color = tex2D(ReShade::BackBuffer, tex_coord + offset).rgb;
                
                float spatial_weight = exp(-dot(offset, offset) * 2.0);
                float color_weight   = exp(-length(sample_color - center) * 5.0);
                float w              = spatial_weight * color_weight;
                
                denoised   += sample_color * w;
                weight_sum += w;
            }
        }
        
        denoised /= weight_sum;
        sharpened = lerp(sharpened, denoised, u_Denoise_Strength);
    }
    
    // Blend with original based on strength
    float3 original = tex2D(ReShade::BackBuffer, tex_coord).rgb;

    return lerp(original, sharpened, u_Upscale_Strength);
}


//**************************************************//
//                  TECHNIQUES                      //
//**************************************************//

technique BMPYM_Upscale
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_BMPYM_Upscale;
    }
}