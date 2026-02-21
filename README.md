# BMPYM ReShade Shaders

A compact collection of ReShade shaders.

## Quick Usage
- Install ReShade and place the `.fx` files in your ReShade shaders folder.
- Load the shaders via ReShade UI and enable/disable them to taste. Most shaders include adjustable parameters exposed in ReShade.

## Shader Summaries
- `BMPYM_BCAS.fx`: Contrast adaptive sharpening (CAS) implementation — improves perceived sharpness post-upscale.
- `BMPYM_BFSMAA.fx`: A high-quality SMAA variant with additional smoothing (FXAA) and tuning for subtle edge handling.
- `BMPYM_Gamma.fx`: Gamma and exposure controls for linear/tonemapped pipelines; useful for correcting display gamma.
- `BMPYM_Vibrant.fx`: Saturation and vibrancy adjustments tuned for the project's palette.
- `Include/`: Shared include files used by the main shaders (helpers, FXAA/SMAA utilities, UI helpers).

## Notes & Tips
- Effects can probably break on some games.
- Recommended to Sharpen after AA.