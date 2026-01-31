// ----------------------------------------------------------------//
//                            Vibrant                              //
//                                                                 //
//  Combines a Dehaze and Vibrancy shaders into a unified		   //
//	shader                       								   //
//      Borrows code from LordOfLunacy Insane-Shaders & 		   //
//		SweetFX Vibrance                 						   //
//  https://github.com/LordOfLunacy/Insane-Shaders				   // 
//  https://github.com/CeeJayDK/SweetFX/tree/master			       // 
//-----------------------------------------------------------------//

//--------------------------------//
#include "Include/BMPYM_Common.fxh"
#include "Include/ReShadeUI.fxh"
//--------------------------------//

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//_____________________________________________________________/\_______________________________________________________________
//==============================================================================================================================
//                                                      Dehaze Component
//==============================================================================================================================

#define CONST_LOG2(x) (\
    (uint((x)  & 0xAAAAAAAA) != 0)      |\
    (uint(((x) & 0xFFFF0000) != 0) << 4)|\
    (uint(((x) & 0xFF00FF00) != 0) << 3)|\
    (uint(((x) & 0xF0F0F0F0) != 0) << 2)|\
    (uint(((x) & 0xCCCCCCCC) != 0) << 1))
	
#define BIT2_LOG2(x)  ((x) | (x) >> 1)
#define BIT4_LOG2(x)  (BIT2_LOG2(x) | BIT2_LOG2(x) >> 2)
#define BIT8_LOG2(x)  (BIT4_LOG2(x) | BIT4_LOG2(x) >> 4)
#define BIT16_LOG2(x) (BIT8_LOG2(x) | BIT8_LOG2(x) >> 8)

#define LOG2(x)           (CONST_LOG2( (BIT16_LOG2(x) >> 1) + 1))
#define MAXIMUM(a, b)     (int((a) > (b)) * (a) + int((b) > (a)) * (b))
#define GET_MAX_MIP(w, h) (LOG2((MAXIMUM((w), (h))) + 1))

#define WINDOW_SIZE 15
#define WINDOW_SIZE_SQUARED (WINDOW_SIZE * WINDOW_SIZE)
#define RENDER_WIDTH        (BUFFER_WIDTH / 4)
#define RENDER_HEIGHT       (BUFFER_HEIGHT / 4)
#define RENDER_RCP_WIDTH    (1/float(RENDER_WIDTH))
#define RENDER_RCP_HEIGHT   (1/float(RENDER_HEIGHT))
#define MAX_MIP GET_MAX_MIP (RENDER_WIDTH, RENDER_HEIGHT)



//**************************************************//
//                  UNIFORMS                        //
//**************************************************//

uniform float Alpha < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0; ui_max = 1;
	ui_label    = "Opacity";
	ui_category = "General";
	
> = 0.5;

uniform float TransmissionMultiplier < __UNIFORM_SLIDER_FLOAT1
	ui_min = -1; ui_max = 1; ui_step = 0.001;
	ui_label    = "Strength";
	ui_category = "General";
	ui_tooltip  = "The overall strength of the removal, positive values correspond to more removal,\n"
				  "and positive values correspond to less.";
> = -0.5;

uniform float DepthMultiplier < __UNIFORM_SLIDER_FLOAT1
	ui_min = -1; ui_max = 1; ui_step = 0.001;
	ui_label    = "Depth Sensitivity";
	ui_category = "General";
	ui_tooltip  = "This setting is for adjusting how much of the removal is depth based, or if\n"
				  "negative values are set, it will actually add fog to the scene. 0 means it is\n"
				  "unaffected by depth.";
> = 0.175;

uniform bool IgnoreSky <
	ui_label   = "Ignore Sky";
	ui_tooltip = "May cause an abrubt transition at the horizon.";
> = 0;

uniform int Debug < __UNIFORM_COMBO_INT1
	ui_items    = "None\0Transmission Map\0";
	ui_label    = "Debug View";
	ui_category = "Debug";
> = 0;



//**************************************************//
//                   TEXTURES                       //
//**************************************************//

texture BackBuffer : COLOR;
texture tMeanTex     		< Pooled = true; > { Width = RENDER_WIDTH; Height = RENDER_HEIGHT; Format = R16f; MipLevels = MAX_MIP; };
texture tVarianceTex 		< Pooled = true; > { Width = RENDER_WIDTH; Height = RENDER_HEIGHT; Format = R16f; MipLevels = MAX_MIP; };
texture tMeanAndVarianceTex < Pooled = true; > { Width = RENDER_WIDTH; Height = RENDER_HEIGHT; Format = RG16f; };
texture tMaximum0Tex 		< Pooled = true; > { Width = RENDER_WIDTH; Height = RENDER_HEIGHT; Format = R8; };
texture tMaximumTex  		< Pooled = true; > { Width = RENDER_WIDTH; Height = RENDER_HEIGHT; Format = R8; MipLevels = MAX_MIP; };

sampler smBackBuffer 	  { Texture = BackBuffer; };
sampler smMean			  { Texture = tMeanTex; };
sampler smVariance 		  { Texture = tVarianceTex; };
sampler smMaximum 		  { Texture = tMaximumTex; };
sampler smMeanAndVariance { Texture = tMeanAndVarianceTex; };
sampler smMaximum0 		  { Texture = tMaximum0Tex; };

texture2D tTempRenderTex  { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler2D smTempRenderTex { Texture = tTempRenderTex; MagFilter = POINT; MinFilter = POINT; MipFilter = POINT;};



//**************************************************//
//                 PIXEL SHADERS                    //
//**************************************************//

void PS_MeanAndVariance0(float4 position : SV_POSITION, float2 texcoord : TEXCOORD, out float2 meanAndVariance : SV_TARGET0, out float maximum : SV_TARGET1)
{
	float darkChannel;
	float sum        = 0;
	float squaredSum = 0;

	maximum = 0;

	for(int i = -(WINDOW_SIZE / 2); i < ((WINDOW_SIZE + 1) / 2); ++i)
	{
			float2 offset = float2(i * RENDER_RCP_WIDTH, 0);
			float3 color  = tex2D(smBackBuffer, texcoord + offset).rgb;

			darkChannel = min(min(color.r, color.g), color.b);

			float darkChannelSquared = darkChannel * darkChannel;
			float darkChannelCubed   = darkChannelSquared * darkChannel;

			sum        += darkChannel;
			squaredSum += darkChannelSquared;

			maximum = max(maximum, darkChannel);
	}
	meanAndVariance = float2(sum, squaredSum);
}


void PS_MeanAndVariance1(float4 position : SV_POSITION, float2 texcoord : TEXCOORD, out float mean : SV_TARGET0, out float variance : SV_TARGET1, out float maximum : SV_TARGET2)
{
	float2 meanAndVariance;
	float sum        = 0;
	float squaredSum = 0;

	maximum = 0;

	for(int i = -(WINDOW_SIZE / 2); i < ((WINDOW_SIZE + 1) / 2); ++i)
	{
			float2 offset   = float2(0, i * RENDER_RCP_HEIGHT);
			meanAndVariance = tex2D(smMeanAndVariance, texcoord + offset).rg;

			sum 	   += meanAndVariance.r;
			squaredSum += meanAndVariance.g;

			maximum = max(maximum, tex2D(smMaximum0, texcoord + offset).r);
	}
	float sumSquared = sum * sum;
	
	mean      = sum / WINDOW_SIZE_SQUARED;
	variance  = (squaredSum - ((sumSquared) / WINDOW_SIZE_SQUARED));
	variance /= WINDOW_SIZE_SQUARED;
}


void PS_WienerFilter(float4 position : SV_POSITION, float2 texcoord : TEXCOORD, out float3 fogRemoved : SV_TARGET0)
{
	float depth = ReShade::GetLinearizedDepth(texcoord);
	
	if(IgnoreSky && depth >= 1) { discard;}
	
	float mean        = tex2D(smMean, texcoord).r;
	float variance    = tex2D(smVariance, texcoord).r;
	float noise       = tex2Dlod(smVariance, float4(texcoord, 0, MAX_MIP - 1)).r;
	float3 color      = tex2D(smBackBuffer, texcoord).rgb;
	float darkChannel = min(min(color.r, color.g), color.b);
	float maximum     = 0;
	float averageGrey = tex2Dlod(smMean, float4(texcoord, 0, MAX_MIP - 1)).r;
	float maxColor    = max(max(color.r, color.g), color.b);
	
	[unroll]
	for(int i = 4; i < MAX_MIP; i++)
	{
		maximum += tex2Dlod(smMaximum, float4(texcoord, 0, i)).r;
	}

	maximum /= MAX_MIP - 4;	
	
	float filter       = saturate((max((variance - noise), 0) / variance) * (darkChannel - mean));
	float veil         = saturate(mean + filter);
	float usedVariance = variance;
	
	float airlight = clamp(maximum, 0.05, 1);
	
	float maxDifference      = maxColor - airlight;
	float thresholdThreshold = airlight - averageGrey;

	float threshold;
	
	if     (thresholdThreshold <= 0.25) { threshold = 0.55; }
	else if (thresholdThreshold < 0.35) { threshold = airlight - averageGrey + 0.4; }
	else 								{ threshold = 0.75; }
	
	float transmission = (((veil * darkChannel) / airlight));

	if(maxDifference < threshold) { transmission = min((threshold / maxColor) * transmission, 1); }

	transmission  = 1 - transmission;
	transmission *= exp(-DepthMultiplier * depth * 0.4);
	transmission *= exp(-TransmissionMultiplier * 0.4);
	transmission  = clamp(transmission, 0.05, 1);  
	

	 
	float y = dot(color, float3(0.299, 0.587, 0.114));
	y       = ((y - airlight) / transmission) + airlight;

	float cb = -0.168736 * color.r - 0.331264 * color.g + 0.500000 * color.b;
	float cr = +0.500000 * color.r - 0.418688 * color.g - 0.081312 * color.b;

	fogRemoved = float3(y + 1.402 * cr, y - 0.344136 * cb - 0.714136 * cr, y + 1.772 * cb);
	fogRemoved = lerp(color, fogRemoved, Alpha);
	
	if(Debug == 1) { fogRemoved = transmission.xxx; }
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//_____________________________________________________________/\_______________________________________________________________
//==============================================================================================================================
//                                                     Vibrance Component
//==============================================================================================================================

//**************************************************//
//                  UNIFORMS                        //
//**************************************************//

uniform float _Vibrance < __UNIFORM_SLIDER_FLOAT1
	ui_min = -1.0; ui_max = 1.0;
	ui_tooltip = "Intelligently saturates (or desaturates if you use negative values) the pixels depending on their original saturation.";
> = 0.15;

uniform float3 _VibranceRGBBalance < __UNIFORM_SLIDER_FLOAT3
	ui_min = 0.0; ui_max = 10.0;
	ui_label   = "RGB Balance";
	ui_tooltip = "A per channel multiplier to the Vibrance strength so you can give more boost to certain colours over others.\nThis is handy if you are colourblind and less sensitive to a specific colour.\nYou can then boost that colour more than the others.";
> = float3(1.0, 1.0, 1.0);



//**************************************************//
//                 PIXEL SHADERS                    //
//**************************************************//

float3 VibrancePass(float4 position : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
	float3 sColour = tex2D(smTempRenderTex, texcoord).rgb;

	float luma = Common::Luminance(sColour);

	float max_colour = max(sColour.r, max(sColour.g, sColour.b)); 
	float min_colour = min(sColour.r, min(sColour.g, sColour.b)); 

	float colourSaturation = max_colour - min_colour; 

	float3 coeffVibrance = float3(_VibranceRGBBalance * _Vibrance);

	float3 fColour = lerp(luma, sColour, 1.0 + (coeffVibrance * (1.0 - (sign(coeffVibrance) * colourSaturation))));

	return fColour;
}



//**************************************************//
//                  TECHNIQUES                      //
//**************************************************//
technique BMPYM_Vibrant <
    ui_label   = "BMPYM Vibrant";
    ui_tooltip =        
        "                     BMPYM - Vibrant                         \n"
        "_____________________________________________________________\n"
        "\n"
        "Vibrant combines a Dehaze and Vibrancy shaders to improve    \n"
        "image clarity and colours.                                   \n"
        "\n"
        "_____________________________________________________________";
>
{
    pass
	{
		VertexShader  = PostProcessVS;
		PixelShader   = PS_MeanAndVariance0;
		RenderTarget0 = tMeanAndVarianceTex;
		RenderTarget1 = tMaximum0Tex;
	}
	
	pass
	{
		VertexShader  = PostProcessVS;
		PixelShader   = PS_MeanAndVariance1;
		RenderTarget0 = tMeanTex;
		RenderTarget1 = tVarianceTex;
		RenderTarget2 = tMaximumTex;
	}
	
	pass
	{
		RenderTarget = tTempRenderTex;
		VertexShader = PostProcessVS;
		PixelShader  = PS_WienerFilter;
	}

	pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = VibrancePass;
	}
}