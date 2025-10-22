import aperture;
import lib.common;
import lib.glsl_barrier;

extern static const float Scene_PostExposureMin;
extern static const float Scene_PostExposureMax;

static const float Exposure_logLumRange = Scene_PostExposureMax - Scene_PostExposureMin;
static const float Exposure_logLumRangeInv = rcp(Exposure_logLumRange);

[[vk::image_format("r32ui")]]
RWTexture1D<uint> imgHistogram;

Sampler2D<float4> texSource;
Sampler2D<float> handDepth;
Sampler2D<float> mainDepthTex;

groupshared Atomic<uint> histogramShared[256];



uint colorToBin(const in float3 hdrColor, const in float minLogLum, const in float inverseLogLumRange) {
	float lum = luminance(hdrColor);
	if (lum < EPSILON) return 0u;

	float logLum = saturate((log2(lum) - minLogLum) * inverseLogLumRange);
	return uint(logLum * 254.0 + 1.0);
}


struct ComputeInput {
    uint groupIndex : SV_GroupIndex;
    uint3 globalPos : SV_DispatchThreadID;
};

[[shader("compute")]]
[numthreads(16, 16, 1)]
void computeHistogram(ComputeInput input) {
	histogramShared[input.groupIndex] = 0u;
	glsl_barrier();

	int2 uv = int2(input.globalPos.xy);
	if (all(uv < int2(ap.game.screenSize))) {
		float3 hdrColor = texSource[uv].rgb;// * BufferLumScale;

		// ignore if hand pixel
		// TODO: FIX THIS LATER! false-positive in water
//		float depthPreHand = textureLod(handDepth, uv, 0).r;
//		float depthPostHand = textureLod(mainDepthTex, uv, 0).r;
//		if (depthPostHand < depthPreHand) hdrColor = vec3(0.0);

		uint binIndex = 128;//colorToBin(hdrColor, Scene_PostExposureMin, Exposure_logLumRangeInv);
		histogramShared[binIndex].increment(MemoryOrder.Relaxed);
	}

	glsl_barrier();

	InterlockedAdd(imgHistogram[input.groupIndex], histogramShared[input.groupIndex].load(MemoryOrder.Relaxed));
}
