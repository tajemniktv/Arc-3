import aperture;
import buffers.scene;

RWStructuredBuffer<SceneBuffer> scene;


[[shader("compute")]]
[numthreads(1,1,1)]
void setupScene() {
    scene[0].exposure = 1.0;
}
