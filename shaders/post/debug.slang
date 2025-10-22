import aperture;
import buffers.scene;
import lib.common;

extern static const float Scene_PostExposureMin;
extern static const float Scene_PostExposureMax;

ConstantBuffer<SceneBuffer> scene;

Sampler1D<uint> texHistogram;

[[shader("fragment")]]
float4 renderDebugOverlay(float2 pos : SV_Position) : SV_Target0 {
    float4 color = float4(0.0);

    float2 previewCoord = (pos - 8.0) / float2(256.0, 32.0);
    if (all(saturate(previewCoord) == previewCoord)) {
        uint sampleVal = texHistogram.SampleLevel(previewCoord.x, 0);
        color.gb = float2(step(previewCoord.y*previewCoord.y, sampleVal / float(ap.game.screenSize.x*ap.game.screenSize.y)));
        color.ra = float2(0.0, 1.0);

        float meter = saturate(unmix(Scene_PostExposureMin, Scene_PostExposureMax, log2(scene.exposure)));
        if (abs(previewCoord.x - meter) < (4.0/ap.game.screenSize.x))
            color.r = 1.0 - color.r;

        // float shit2 = saturate(unmix(Scene_PostExposureMin, Scene_PostExposureMax, log2(Scene_AvgExposure) + Post_ExposureOffset));
        // if (abs(previewCoord.x - shit2) < 0.008)
        //     color.b = 1.0 - color.b;
    }

    return color;
}
