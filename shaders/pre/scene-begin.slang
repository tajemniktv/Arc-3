import aperture;
import buffers.scene;
import lib.common;
import lib.sky.common;

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
    
    scene[0].SunColor = RgbToLinear(float3(1.0, 0.98, 0.92)) * SUN_LUMINANCE;
    scene[0].SunLocalDir = normalize(mul(float3x3(ap.camera.viewInv), ap.celestial.sunPosition));

    scene[0].MoonColor = RgbToLinear(float3(0.92, 0.94, 1.0)) * MOON_LUMINANCE;
    scene[0].MoonLocalDir = normalize(mul(float3x3(ap.camera.viewInv), ap.celestial.moonPosition));
}
