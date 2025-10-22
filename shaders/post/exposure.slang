import aperture;
import buffers.scene;
import lib.glsl_barrier;

extern static const bool DEBUG_HISTOGRAM = false;
extern static const float Scene_PostExposureMin = -4.0;
extern static const float Scene_PostExposureMax = 34.0;
extern static const float Scene_PostExposureSpeed = 0.8;

static const float Exposure_logLumRange = Scene_PostExposureMax - Scene_PostExposureMin;
static const float Exposure_logLumRangeInv = rcp(Exposure_logLumRange);

RWStructuredBuffer<SceneBuffer> scene;

[[vk::image_format("r32ui")]]
RWTexture1D<uint> imgHistogram;

// #ifdef DEBUG_EXPOSURE
// 	layout(r32ui) uniform uimage2D imgHistogram_debug;
// #endif

groupshared uint histogramShared[256];


[[shader("compute")]]
[numthreads(256, 1, 1)]
void computeExposure(uint groupIndex : SV_GroupIndex) {
	uint countForThisBin = imgHistogram[groupIndex];
	histogramShared[groupIndex] = countForThisBin * groupIndex;

	glsl_barrier();

	// #ifdef DEBUG_EXPOSURE
	// 	imageStore(imgHistogram_debug, histogram_uv, uvec4(countForThisBin));
	// #endif

	if (!DEBUG_HISTOGRAM) {
		imgHistogram[groupIndex] = 0u;
	}

	// This loop will perform a weighted count of the luminance range
	for (uint cutoff = (256u >> 1u); cutoff > 0u; cutoff >>= 1u) {
		if (uint(groupIndex) < cutoff) {
			histogramShared[groupIndex] += histogramShared[groupIndex + cutoff];
		}

		glsl_barrier();
	}

	if (groupIndex == 0) {
		// Here we take our weighted sum and divide it by the number of pixels
		// that had luminance greater than zero (since the index == 0, we can
		// use countForThisBin to find the number of black pixels)
		float Exposure_numPixels = ap.game.screenSize.x * ap.game.screenSize.y;
		float nonBlackPixelCount = Exposure_numPixels - countForThisBin;
		float weightedLogAverage = (histogramShared[0] / max(nonBlackPixelCount, 1.0)) - 1.0;

		// Map from our histogram space to actual luminance
		float weightedAvgLum = exp2((weightedLogAverage/254.0 * Exposure_logLumRange) + Scene_PostExposureMin);
		float adaptedLum = weightedAvgLum;

		// do not mix if first rendered frame
		if (ap.timing.frameCounter != 0) {
			float timeF = 1.0 - exp(-max(Scene_PostExposureSpeed * ap.timing.lastFrameTime, 1.0e-12));

//			float lumLastFrame = clamp(Scene_AvgExposure, 0.0, 99999.0);
			float lumLastFrame = max(scene[0].exposure, 0.0);
			adaptedLum = lumLastFrame + (weightedAvgLum - lumLastFrame) * timeF;
		}

		scene[0].exposure = adaptedLum;
	}
}
