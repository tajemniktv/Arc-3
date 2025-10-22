import aperture;

Sampler1D<uint> texHistogram;

[[shader("fragment")]]
float4 renderDebugOverlay(float2 pos : SV_Position) : SV_Target0 {
    float4 color = float4(0.0);

    float2 previewCoord = (pos - 8.0) / float2(80.0, 16.0);
    if (all(saturate(previewCoord) == previewCoord)) {
        uint sampleVal = texHistogram.SampleLevel(previewCoord.x, 0);
        color.gb = float2(step(previewCoord.y*previewCoord.y, sampleVal / (ap.game.screenSize.x*ap.game.screenSize.y)));
        color.ra = float2(0.0, 1.0);

        // float shit = saturate(unmix(Scene_PostExposureMin, Scene_PostExposureMax, log2(Scene_AvgExposure)));
        // if (abs(previewCoord.x - shit) < 0.008)
        //     color.g = 1.0 - color.g;

        // float shit2 = saturate(unmix(Scene_PostExposureMin, Scene_PostExposureMax, log2(Scene_AvgExposure) + Post_ExposureOffset));
        // if (abs(previewCoord.x - shit2) < 0.008)
        //     color.b = 1.0 - color.b;
    }

    return color;
}
