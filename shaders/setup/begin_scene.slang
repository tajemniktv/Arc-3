import aperture;
import buffers.scene;

RWStructuredBuffer<SceneBuffer> ssboScene;


[[shader("compute")]]
[numthreads(1,1,1)]
void beginScene() {
    const float jitter_g = 1.32471795724474602596;
    const float2 jitter_vec = 1.0 / float2(jitter_g, jitter_g*jitter_g);

    float2 jitter_offset = frac(jitter_vec * ap.timing.frameCounter + 0.5) - 0.5;
    ssboScene[0].taa_jitter = jitter_offset / ap.game.screenSize;
}
