import aperture;
import buffers.sky;
import buffers.scene;
import lib.common;
import lib.sky.common;

extern static const int DIMENSION;

RWStructuredBuffer<SceneBuffer> scene;


[[shader("compute")]]
[numthreads(1,1,1)]
void setupScene() {
    scene[0].exposure = 1.0;

    if (DIMENSION == DIM_END) {
        scene[0].sky = skyEnd;
        scene[0].SunColor = RgbToLinear(float3(0.780, 0.196, 0.620)) * 60.0;
        scene[0].MoonColor = 0.0;
    }
    else {
        scene[0].sky = skyClear;
        scene[0].SunColor = RgbToLinear(float3(1.0, 0.98, 0.92)) * SUN_LUMINANCE;
        scene[0].MoonColor = RgbToLinear(float3(0.92, 0.94, 1.0)) * MOON_LUMINANCE;
    }
}
