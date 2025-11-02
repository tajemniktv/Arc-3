import aperture;
import buffers.scene;
import buffers.sky;
import lib.common;
import lib.light.floodfill;

extern static const int DIMENSION;
extern static const bool TAA_Enabled;

RWStructuredBuffer<SceneBuffer> scene;


float2 getTaaJitter() {
    const float jitter_g = 1.32471795724474602596;
    const float2 jitter_vec = 1.0 / float2(jitter_g, jitter_g*jitter_g);
    return frac(jitter_vec * ap.timing.frameCounter + 0.5) - 0.5;
}


[[shader("compute")]]
[numthreads(1,1,1)]
void beginScene() {
    if (TAA_Enabled) {
        scene[0].taa_jitter = getTaaJitter() / ap.game.screenSize;
    }
    
    scene[0].SunLocalDir = normalize(mul(float3x3(ap.camera.viewInv), ap.celestial.sunPosition));
    scene[0].MoonLocalDir = normalize(mul(float3x3(ap.camera.viewInv), ap.celestial.moonPosition));
    scene[0].SkyLightLocalDir = normalize(mul(float3x3(ap.camera.viewInv), ap.celestial.position));

    for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
        scene[0].shadowViewMin[i] = mul3(ap.celestial.projectionInv[i], float3(-1.0, -1.0, 0.0)).xy;
        scene[0].shadowViewMax[i] = mul3(ap.celestial.projectionInv[i], float3( 1.0,  1.0, 0.0)).xy;
    }

    if (DIMENSION != DIM_END) {
        lerp(skyClear, skyRain, ap.world.rainStrength, scene[0].sky);
    }

    scene[0].FloodFillCenter = GetVoxelCenter(ap.camera.position);
}
